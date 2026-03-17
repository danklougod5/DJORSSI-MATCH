
import os
import requests
import json
from dotenv import load_dotenv

load_dotenv()

def list_models():
    url = "https://openrouter.ai/api/v1/models"
    response = requests.get(url)
    if response.status_code == 200:
        models = response.json().get('data', [])
        with open('or_models.json', 'w') as f:
            json.dump(models, f, indent=2)
        print("Models saved to or_models.json")
    else:
        print(f"Failed to list models: {response.status_code}")

if __name__ == "__main__":
    list_models()
