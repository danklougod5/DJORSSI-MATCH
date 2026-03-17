
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
        # Find free models
        free_models = [m['id'] for m in models if 'free' in m['id']]
        print("Free models:", free_models[:10])
    else:
        print(f"Failed to list models: {response.status_code}")

if __name__ == "__main__":
    list_models()
