
import os
import requests
import json
from dotenv import load_dotenv

load_dotenv()

def find_and_test_model():
    url_models = "https://openrouter.ai/api/v1/models"
    url_chat = "https://openrouter.ai/api/v1/chat/completions"
    key = os.environ.get("OPENROUTER_API_KEY")
    headers = {"Authorization": f"Bearer {key}"}
    
    print("Fetching models...")
    resp = requests.get(url_models)
    if resp.status_code != 200:
        print(f"Failed to fetch models: {resp.status_code}")
        return

    models = resp.json().get('data', [])
    free_models = [m['id'] for m in models if 'free' in m['id']]
    print(f"Found {len(free_models)} free models.")
    
    # Try the first few free models
    for model_id in free_models[:5]:
        print(f"Testing model: {model_id}...")
        data = {
            "model": model_id,
            "messages": [{"role": "user", "content": "Say hello"}]
        }
        r = requests.post(url_chat, headers=headers, json=data)
        if r.status_code == 200:
            print(f"SUCCESS! Model {model_id} works.")
            print("Response:", r.json()['choices'][0]['message']['content'])
            return model_id
        else:
            print(f"Model {model_id} failed with status {r.status_code}: {r.text[:100]}")
    
    return None

if __name__ == "__main__":
    find_and_test_model()
