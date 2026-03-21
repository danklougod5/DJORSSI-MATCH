import os
import json
import time
import requests
from dotenv import load_dotenv

load_dotenv()

class AIJobValidator:
    def __init__(self):
        self.ollama_model = os.environ.get("OLLAMA_MODEL", "qwen2.5:7b")
        self.ollama_url = "http://localhost:11434/api/chat"
        self.providers = ["ollama"]
        print(f"[OK] AI Validator initialized with Ollama ({self.ollama_model}).")

    async def _call_ollama(self, prompt):
        """Appelle l'API Ollama locale pour analyser l'offre d'emploi en asynchrone."""
        import httpx
        data = {
            "model": self.ollama_model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
            "format": "json"
        }
        
        try:
            # Timeout plus court car on tourne en asynchrone
            async with httpx.AsyncClient() as client:
                response = await client.post(self.ollama_url, json=data, timeout=300.0)
                if response.status_code == 200:
                    result = response.json()
                    content = result['message']['content'].strip()
                    
                    # Extraction du JSON propre
                    if "{" in content:
                        content = content[content.find("{"):content.rfind("}")+1]
                    return json.loads(content)
                else:
                    print(f"  [ERROR] Ollama HTTP {response.status_code}")
                    return None
        except Exception as e:
            print(f"  [ERROR] Ollama Error: {repr(e)}")
            return None

    async def validate_and_clean_job(self, raw_text: str):
        prompt = f"""
        Extract job information from the following raw text and return it strictly as a valid JSON object.
        If the text is NOT a job offer, return {{"is_job": false}}.
        
        Fields expected in the JSON:
        - "job_title": Clean title (e.g., 'Comptable' instead of 'Poste de comptable H/F')
        - "company_name": Name of the hiring company (Return 'Non spécifié' if not found in text)
        - "specialty": Field of work
        - "contract_type": CDD, CDI, Stage, etc.
        - "salary_range": If mentioned
        - "description": Brief summary
        - "tags": Array of tags
        - "location": Precise city/commune (e.g., 'Cocody', 'Plateau')
        - "experience": Clear experience requirement (e.g., '7 ans', 'Senior')
        - "required_level": Minimum education level (e.g., 'BAC+5', 'Licence')
        - "contact_email": The extracted email. IMPORTANT: ALWAYS extract if ending in @educarriere.net !
        - "whatsapp_number": The extracted phone number
        
        CRITICAL: If you cannot find ANY valid contact_email OR whatsapp_number, you MUST return {{"is_job": false}}.
        - "deadline": Deadline in YYYY-MM-DD (ONLY if explicitly written in the text, otherwise null).
          Look for phrases like: "Date limite", "Date limite de dépôt", "Date limite de candidature",
          "avant le", "au plus tard le", "deadline", "date de clôture".
          Examples: "avant le 30 mars 2026" → "2026-03-30", "Date limite: 30/03/2026" → "2026-03-30"
        - "benefits": Any perks mentioned
        - "is_ai_verified": true

        Available Tags (Use only these or similar from this list):
        'Informatique', 'Marketing', 'Vente', 'Ressources Humaines',
        'Finance', 'Logistique', 'Ingénierie', 'Design', 'Administration',
        'Télécommunications', 'BTP', 'Santé', 'Éducation', 'Juridique',
        'Banque & Assurance', 'Commerce', 'Transport', 'Hôtellerie'.

        Critical Rules:
        1. Only return is_job: true if the offer is definitely for Côte d'Ivoire AND contains a REAL contact email OR a WhatsApp number.
        2. EXCEPTION: If the email found is "[email protected]" or "email-protection" or any placeholder, treat it as if NO email was found.
        3. If neither a real email nor a WhatsApp number is found, return {{"is_job": false}}.
        4. Translate everything to French.
        5. Map the job to at least 1-3 appropriate tags from the 'Available Tags' list.
        6. NEVER INVENT DATA. If a field is not in the text, return null or empty string. Do NOT guess dates, emails, or phone numbers.
        7. MANDATORY: If the text contains an email address (even if it ends in @educarriere.net), you MUST set it as contact_email! Do not ignore it!

        Raw Text:
        {raw_text}
        """
        
        # Un seul moteur désormais : Ollama (Local)
        return await self._call_ollama(prompt)
