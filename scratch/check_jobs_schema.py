import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv(dotenv_path="scraper/.env")

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    print("Error: credentials missing")
    exit(1)

supabase: Client = create_client(url, key)
res = supabase.table("jobs").select("*").limit(1).execute()
if res.data:
    print("Columns in jobs table:")
    for key in res.data[0].keys():
        print(f"- {key}: {type(res.data[0][key])}")
else:
    print("No data in jobs table to read schema from.")
