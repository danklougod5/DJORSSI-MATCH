import sys
import os
import json
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('jobs').select('*').limit(50).execute()
    with open('jobs_dump.json', 'w') as f:
        json.dump(res.data, f)
except Exception as e:
    print("Error:", e)
