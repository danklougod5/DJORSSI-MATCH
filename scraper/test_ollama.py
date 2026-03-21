import os
import requests
import json
from dotenv import load_dotenv

load_dotenv()

# We look for the model from .env
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen2.5:7b")
OLLAMA_URL = "http://localhost:11434/api/chat"

print(f"Testing Ollama with model: {OLLAMA_MODEL}...")

try:
    # Basic ping to check if Ollama is running
    data = {
        "model": OLLAMA_MODEL,
        "messages": [{"role": "user", "content": "Return 'pong' in JSON format: {'response': 'pong'}"}],
        "stream": False,
        "format": "json"
    }
    
    response = requests.post(OLLAMA_URL, json=data, timeout=10)
    if response.status_code == 200:
        result = response.json()
        print("\n[SUCCESS] Ollama is responding!")
        print(f"Response content: {result['message']['content']}")
        print("\nYour scraper is now configured to use Ollama as a priority fallback.")
    else:
        print(f"\n[ERROR] Ollama returned HTTP {response.status_code}")
        print("Check if Ollama is running and handles the specified model.")

except Exception as e:
    print(f"\n[ERROR] Request failed: {e}")
    print("Is Ollama running? Start it with 'ollama serve' and make sure you have pulled the model with 'ollama pull qwen2.5:7b'")
