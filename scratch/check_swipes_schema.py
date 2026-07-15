import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('swipes_log').select('*').limit(1).execute()
    if res.data:
        print("Columns:", list(res.data[0].keys()))
    else:
        print("No rows found in swipes_log to inspect schema.")
except Exception as e:
    print("Error:", e)
