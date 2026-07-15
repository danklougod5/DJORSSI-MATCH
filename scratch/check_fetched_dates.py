import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    
    # Check creation dates of some jobs returned to the device
    device_job_ids = [
        "5b195c72-28e6-41e6-81d5-5d3aa5ff4f7b",
        "14518a2a-5ad7-41a6-b0d4-4c8e7741adc6",
        "c008d677-79bb-4c8f-9618-79290a757883"
    ]
    res = db.supabase.table('jobs').select('id, job_title, created_at').in_('id', device_job_ids).execute()
    for j in res.data:
        print(f"- ID: {j['id']} | Created: {j['created_at']} | Title: {j['job_title']}")
        
    print("\nAlso checking if the recent anglais jobs are in the db and their created_at:")
    recent_anglais_ids = [
        "523e7cf6-7fb9-43ba-abba-e46d05ec5c19",
        "d9740d90-46d8-4456-bfec-345eadfa0953",
        "6057236e-afd7-4a3d-a3e3-b62105bea6df"
    ]
    res_anglais = db.supabase.table('jobs').select('id, job_title, created_at').in_('id', recent_anglais_ids).execute()
    for j in res_anglais.data:
        print(f"- ID: {j['id']} | Created: {j['created_at']} | Title: {j['job_title']}")
        
except Exception as e:
    print("Error:", e)
