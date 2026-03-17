import os
import google.generativeai as genai
from dotenv import load_dotenv
import time

load_dotenv()

def test_models():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("GEMINI_API_KEY not found")
        return
    
    genai.configure(api_key=api_key)
    models_to_try = [
        'gemini-1.5-flash',
        'gemini-1.5-flash-latest',
        'gemini-2.0-flash',
        'gemini-2.0-flash-exp'
    ]
    
    for m_name in models_to_try:
        print(f"\nTrying {m_name}...")
        try:
            model = genai.GenerativeModel(m_name)
            response = model.generate_content("test")
            print(f"  [OK] Response: {response.text[:20]}")
            break # Stop if one works
        except Exception as e:
            print(f"  [FAIL] {m_name}: {e}")
            time.sleep(1)

if __name__ == "__main__":
    test_models()
