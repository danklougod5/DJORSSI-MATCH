import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    
    # Query jobs
    res = db.supabase.table('jobs').select('id, job_title, tags, is_approved, created_at').eq('is_approved', True).order('created_at', desc=True).execute()
    jobs = res.data
    
    anglais_jobs = []
    for job in jobs:
        title = job.get('job_title', '').lower()
        tags = [t.lower() for t in (job.get('tags') or [])]
        if 'anglais' in tags or 'anglais' in title or 'bilingue' in tags:
            anglais_jobs.append(job)
            
    print(f"Total approved jobs: {len(jobs)}")
    print(f"Jobs matching 'anglais' or 'bilingue': {len(anglais_jobs)}")
    for j in anglais_jobs[:10]:
        print(f"- ID: {j['id']} | Created: {j['created_at']} | Title: {j['job_title']} | Tags: {j['tags']}")
        
except Exception as e:
    print("Error:", e)
