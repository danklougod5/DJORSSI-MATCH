import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('profiles').select('id, full_name, daily_swipe_count, last_swipe_date').gt('daily_swipe_count', 0).execute()
    print(f"Profiles with daily_swipe_count > 0: {len(res.data)}")
    for p in res.data[:20]:
        print(p)
except Exception as e:
    print("Error:", e)
