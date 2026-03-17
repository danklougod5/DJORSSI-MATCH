
import os
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

def test_openrouter():
    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        print("No key found")
        return
        
    client = OpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key=key,
    )
    
    try:
        print("Testing OpenRouter with Gemini Flash Lite...")
        response = client.chat.completions.create(
            model="google/gemini-2.0-flash-lite-preview-02-05:free",
            messages=[{"role": "user", "content": "Say hello"}],
        )
        print("Response:", response.choices[0].message.content)
    except Exception as e:
        print(f"OpenRouter failed: {e}")

if __name__ == "__main__":
    test_openrouter()
