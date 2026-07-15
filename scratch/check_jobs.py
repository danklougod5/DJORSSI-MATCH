import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    
    # Query the 50 most recent approved jobs
    res = db.supabase.table('jobs').select('id, job_title, tags, is_approved, created_at').eq('is_approved', True).order('created_at', desc=True).limit(50).execute()
    
    jobs = res.data
    print(f"Total jobs fetched (limit 50): {len(jobs)}")
    
    for i, job in enumerate(jobs):
        title = job.get('job_title', '').lower()
        tags = [t.lower() for t in (job.get('tags') or [])]
        matched = 'anglais' in tags or 'anglais' in title or 'bilingue' in tags
        if matched:
            print(f"Recent Job #{i+1}: ID: {j['id'] if 'j' in locals() else job['id']} | Title: {job['job_title']} | Tags: {job['tags']}")
        
except Exception as e:
    print("Error:", e)
