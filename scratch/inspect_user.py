import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('profiles').select('*').ilike('full_name', '%Dobgo%').execute()
    
    print("=== DOBGO PROFILES ===")
    profiles = res.data
    for p in profiles:
        print(p)
        print("-" * 50)
        
        # Check swipes
        user_id = p['id']
        swipes_res = db.supabase.table('swipes_log').select('id, job_id, created_at').eq('user_id', user_id).execute()
        print(f"Swipes count in swipes_log: {len(swipes_res.data)}")
        for sw in swipes_res.data[:20]:
            print(f"  Swipe: job_id={sw['job_id']} created_at={sw['created_at']}")
        if len(swipes_res.data) > 20:
            print("  ...")
except Exception as e:
    print("Error:", e)
