import os
from supabase import create_client
from dotenv import load_dotenv

# Load env from app folder
load_dotenv("/Users/mac/DJORSSI-MATCH/app/.env")

url = os.environ.get("SUPABASE_URL")
anon_key = os.environ.get("SUPABASE_ANON_KEY")

print(f"Supabase URL: {url}")
supabase = create_client(url, anon_key)

try:
    print("Attempting to sign in with new credentials...")
    res = supabase.auth.sign_in_with_password({
        "email": "danklougod5@gmail.com",
        "password": "Arielle@008"
    })
    print("Success! User ID:", res.user.id)
    print("Confirmed at:", res.user.email_confirmed_at)
    print("User Metadata:", res.user.user_metadata)
except Exception as e:
    print("Sign in failed! Error:")
    print(e)
