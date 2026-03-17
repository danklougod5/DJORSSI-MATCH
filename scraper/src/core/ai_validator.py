import os
import json
import time
import requests
from dotenv import load_dotenv

# Mistral
from mistralai.client import Mistral
import google.generativeai as genai

load_dotenv()

class AIJobValidator:
    def __init__(self):
        self.mistral_clients = []
        self.current_mistral_idx = 0
        self.openrouter_key = os.environ.get("OPENROUTER_API_KEY")
        
        # Load multiple Mistral keys from distinct env vars
        i = 1
        while True:
            key = os.environ.get(f"MISTRAL_KEY_{i}")
            if not key:
                if i == 1:
                    key = os.environ.get("MISTRAL_API_KEY")
                if not key:
                    break
            
            try:
                client = Mistral(api_key=key)
                self.mistral_clients.append(client)
                print(f"[OK] Mistral Key #{i} initialized.")
            except Exception as e:
                print(f"[WARN] Failed to init Mistral Key #{i}: {e}")
            
            i += 1

        if self.openrouter_key:
            print("[OK] OpenRouter key loaded.")

        self.providers = []
        if self.mistral_clients:
            self.providers.append("mistral")
        if self.openrouter_key:
            self.providers.append("openrouter")
        if os.environ.get("GEMINI_API_KEY"):
            self.providers.append("gemini")
        if os.environ.get("GROQ_API_KEY"):
            self.providers.append("groq")

        if not self.providers:
            print("[ERROR] No AI clients initialized. Scraper will fail validation.")

    def _rotate_mistral(self):
        if len(self.mistral_clients) > 1:
            self.current_mistral_idx = (self.current_mistral_idx + 1) % len(self.mistral_clients)
            print(f"  [ROTATE] Switched to Mistral Key #{self.current_mistral_idx + 1}")
            return True
        return False

    def _call_mistral(self, prompt):
        if not self.mistral_clients:
            return None
            
        client = self.mistral_clients[self.current_mistral_idx]
        response = client.chat.complete(
            model="mistral-small-latest",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"}
        )
        content = response.choices[0].message.content.strip()
        return json.loads(content)

    def _call_openrouter(self, prompt):
        if not self.openrouter_key:
            return None
            
        url = "https://openrouter.ai/api/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.openrouter_key}",
            "Content-Type": "application/json"
        }
        
        # Use a model that we know works and is free
        model_id = "nvidia/nemotron-3-super-120b-a12b:free"
        data = {
            "model": model_id,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1
        }
        
        try:
            response = requests.post(url, headers=headers, json=data, timeout=30)
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['message']['content'].strip()
                
                # Extract JSON from potential markdown or text
                if "{" in content:
                    content = content[content.find("{"):content.rfind("}")+1]
                return json.loads(content)
            else:
                print(f"  [ERROR] OpenRouter HTTP {response.status_code}: {response.text[:200]}")
                return None
        except Exception as e:
            print(f"  [ERROR] OpenRouter request failed: {e}")
            return None

    def _call_gemini(self, prompt):
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            return None
        
        try:
            # Add a small delay for Gemini free tier (15 RPM)
            time.sleep(4) 
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel('models/gemini-2.0-flash', generation_config={"response_mime_type": "application/json"})
            response = model.generate_content(prompt)
            return json.loads(response.text)
        except Exception as e:
            print(f"  [ERROR] Gemini request failed: {e}")
            return None

    def _call_groq(self, prompt):
        api_key = os.environ.get("GROQ_API_KEY")
        if not api_key:
            return None
        
        url = "https://api.groq.com/openai/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        data = {
            "model": "llama-3.3-70b-versatile",
            "messages": [{"role": "user", "content": prompt}],
            "response_format": {"type": "json_object"}
        }
        
        try:
            response = requests.post(url, headers=headers, json=data, timeout=30)
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['message']['content'].strip()
                return json.loads(content)
            else:
                print(f"  [ERROR] Groq HTTP {response.status_code}: {response.text[:200]}")
                return None
        except Exception as e:
            print(f"  [ERROR] Groq request failed: {e}")
            return None

    def validate_and_clean_job(self, raw_text: str):
        prompt = f"""
        Extract job information from the following raw text and return it strictly as a valid JSON object.
        If the text is NOT a job offer, return {{"is_job": false}}.
        
        Fields:
        - job_title, company_name, specialty, contract_type, salary_range, location, 
        - required_level, experience, contact_email, whatsapp_number, description, tags, deadline.
        - is_ai_verified: true.

        Critical Rules:
        1. Only return is_job: true if the offer is definitely for Côte d'Ivoire AND contains a REAL contact email OR a WhatsApp number.
        2. EXCEPTION: If the email found is "[email protected]" or "email-protection" or any placeholder, treat it as if NO email was found.
        3. If neither a real email nor a WhatsApp number is found, return {{"is_job": false}}.
        4. Translate everything to French.

        Raw Text:
        {raw_text}
        """
        
        # 1. Try Mistral (with rotation)
        if self.mistral_clients:
            num_keys = len(self.mistral_clients)
            for attempt in range(num_keys):
                try:
                    return self._call_mistral(prompt)
                except Exception as e:
                    err_text = str(e).lower()
                    if any(x in err_text for x in ["429", "rate_limit", "insufficient_quota", "quota exceeded", "limit"]):
                        print(f"  [LIMIT] Mistral Key #{self.current_mistral_idx + 1} reached limit.")
                    else:
                        print(f"  [ERROR] Mistral Key #{self.current_mistral_idx + 1} failed: {e}")
                    
                    if num_keys > 1 and attempt < num_keys - 1:
                        self._rotate_mistral()
                        continue
                    else:
                        print("  [INFO] All Mistral keys exhausted.")
                        break

        # 2. Try OpenRouter as fallback
        if self.openrouter_key:
            print("  [FALLBACK] Attempting OpenRouter (Nvidia Nemotron)...")
            result = self._call_openrouter(prompt)
            if result:
                print("  [OK] OpenRouter fallback successful.")
                return result
            else:
                print("  [ERROR] OpenRouter fallback failed.")
        
        # 3. Try Gemini as final fallback
        if "gemini" in self.providers:
            for g_attempt in range(2): # Try Gemini twice if 429
                print(f"  [FALLBACK] Attempting Gemini Flash (Attempt {g_attempt+1})...")
                result = self._call_gemini(prompt)
                if result:
                    print("  [OK] Gemini fallback successful.")
                    return result
                else:
                    print("  [WAIT] Gemini busy or limit reached. Sleeping 30s...")
                    time.sleep(30)
        
        # 4. Try Groq as final fallback
        if "groq" in self.providers:
            print("  [FALLBACK] Attempting Groq (Llama 3)...")
            result = self._call_groq(prompt)
            if result:
                print("  [OK] Groq fallback successful.")
                return result
            else:
                print("  [ERROR] Groq fallback failed.")
        
        return None
