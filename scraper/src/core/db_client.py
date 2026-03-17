import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

class SupabaseClient:
    def __init__(self):
        url: str = os.environ.get("SUPABASE_URL")
        key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        
        if not url or not key or url == "your_project_url":
            print("[ERROR] SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing in .env")
            self.supabase = None
            return

        try:
            self.supabase: Client = create_client(url, key)
            print("[OK] Supabase Client initialized.")
        except Exception as e:
            print(f"[ERROR] Failed to initialize Supabase Client: {e}")
            self.supabase = None

    def insert_job(self, data: dict):
        if not self.supabase:
            print("[ERROR] Cannot insert: Supabase client not initialized.")
            return None
        try:
            return self.supabase.table("jobs").upsert(data, on_conflict="source_url").execute()
        except Exception as e:
            print(f"Error inserting job: {e}")
            return None
