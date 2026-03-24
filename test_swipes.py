import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('swipes_log').select('job_id', count='exact').execute()
    print("Total swipes:", len(res.data))
    
    # Check how many jobs are IT
    res2 = db.supabase.table('jobs').select('id, tags').execute()
    it_count = sum(1 for job in res2.data if job.get('tags') and 'Informatique' in job['tags'])
    print("Total IT jobs:", it_count)
except Exception as e:
    print("Error:", e)
