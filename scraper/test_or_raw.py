
import os
import requests
import json
from dotenv import load_dotenv

load_dotenv()

def test_or_raw():
    key = os.environ.get("OPENROUTER_API_KEY")
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {key}",
    }
    
    models = ["google/gemini-2.0-flash-lite-preview-02-05:free", "meta-llama/llama-3-8b-instruct:free"]
    
    for model in models:
        data = {
            "model": model,
            "messages": [{"role": "user", "content": "Say hello"}]
        }
        print(f"\n--- Testing model: {model} ---")
        try:
            response = requests.post(url, headers=headers, json=data)
            print(f"Status: {response.status_code}")
            try:
                print(json.dumps(response.json(), indent=2))
            except:
                print(f"Raw Text: {response.text}")
        except Exception as e:
            print(f"Request failed: {e}")

if __name__ == "__main__":
    test_or_raw()
