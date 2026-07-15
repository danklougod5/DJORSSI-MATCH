import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('profiles').select('*').ilike('full_name', '%dody%').execute()
    
    print("=== DODY PROFILES ===")
    for p in res.data:
        print(p)
        print("-" * 50)
except Exception as e:
    print("Error:", e)
