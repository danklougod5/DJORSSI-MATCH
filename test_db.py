import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('profiles').select('full_name, skills').execute()
    print("Profiles:", res.data)
except Exception as e:
    print("Error:", e)
