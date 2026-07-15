import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('swipes_log').select('user_id').limit(10).execute()
    print("Recent swipe logs:")
    for row in res.data:
        print(row)
        
    res2 = db.supabase.table('swipes_log').select('id', count='exact').execute()
    print("Total rows in swipes_log:", len(res2.data))
except Exception as e:
    print("Error:", e)
