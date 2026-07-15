import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv("app/.env")

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_ANON_KEY")

if not url or not key:
    print("Missing env vars")
    exit(1)

supabase: Client = create_client(url, key)

try:
    # Try to select from app_config to see what columns it has
    res = supabase.from_('app_config').select('*').limit(1).execute()
    print("Columns:", res.data[0].keys() if res.data else "No data")
except Exception as e:
    print("Error:", e)
