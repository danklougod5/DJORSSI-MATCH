import json
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('jobs').select('job_title, tags').execute()
    for job in res.data:
        title = job.get('job_title', '').lower()
        tags = [t.lower() for t in (job.get('tags') or [])]
        if 'secretaire' in title or 'secretariat' in title or 'assistante' in title:
            print(f"TITLE: {job['job_title']}, TAGS: {job['tags']}")
except Exception as e:
    print(e)
