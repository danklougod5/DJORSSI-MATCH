import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('profiles').select('id, full_name, is_premium, premium_until, show_premium').ilike('full_name', '%dody%').execute()
    print("Dody profile:", res.data)
except Exception as e:
    print("Error:", e)
