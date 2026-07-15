import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    
    # Get total records count in swipes_log
    res = db.supabase.table('swipes_log').select('id', count='exact').limit(1).execute()
    print("Exact count of swipes_log in database:", res.count if hasattr(res, 'count') else "unknown")
    
    # Let's list some swipes if any
    res_list = db.supabase.table('swipes_log').select('id, user_id, job_id, direction, created_at').limit(5).execute()
    print("Some swipes:")
    for s in res_list.data:
        print(s)
        
except Exception as e:
    print("Error:", e)
