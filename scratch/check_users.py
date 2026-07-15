import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('profiles').select('id, full_name, email, cv_url').not_.is_('cv_url', 'null').execute()
    print("PROFILES WITH CV:")
    for row in res.data:
        print(row)
except Exception as e:
    print("Error:", e)
