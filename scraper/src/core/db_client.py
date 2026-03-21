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

    def url_exists(self, url: str) -> bool:
        """Checks if a job with this source_url already exists."""
        if not self.supabase: return False
        try:
            res = self.supabase.table("jobs").select("id").eq("source_url", url).execute()
            return len(res.data) > 0
        except:
            return False

    def log(self, level: str, message: str):
        """Only print to terminal, skip database insertion to save space."""
        print(f"[{level}] {message}", flush=True)
        return None
