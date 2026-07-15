import sys
import os
import json

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('jobs').select('*').eq('is_approved', True).execute()
    print(f"Fetched {len(res.data)} approved jobs.")
    with open('jobs_dump.json', 'w', encoding='utf-8') as f:
        json.dump(res.data, f, ensure_ascii=False, indent=2)
    print("Successfully wrote jobs to jobs_dump.json")
except Exception as e:
    print("Error:", e)
