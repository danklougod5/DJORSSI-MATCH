import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    
    # Simulate the query with server-side filtering
    res = db.supabase.table('jobs') \
        .select('id, job_title, tags, created_at') \
        .eq('is_approved', True) \
        .or_('tags.cs.{"Anglais"},job_title.ilike.%Anglais%') \
        .order('created_at', desc=True) \
        .limit(50) \
        .execute()
        
    jobs = res.data
    print(f"Server-side filtered query returned {len(jobs)} jobs:")
    for i, job in enumerate(jobs):
        print(f"#{i+1}: ID: {job['id']} | Title: {job['job_title']} | Tags: {job['tags']}")
        
except Exception as e:
    print("Error:", e)
