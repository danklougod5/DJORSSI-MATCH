import os
from mistralai import Mistral
from dotenv import load_dotenv

load_dotenv()
api_key = os.environ.get("MISTRAL_API_KEY")

try:
    print(f"Key loaded: {api_key[:5]}...")
    client = Mistral(api_key=api_key)
    print("Client init success!")
except Exception as e:
    import traceback
    traceback.print_exc()
