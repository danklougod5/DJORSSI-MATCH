import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    # Attempt to read as admin/service_role
    res = db.supabase.table('ios_waitlist').select('*').execute()
    print("Rows in DB:", res.data)
except Exception as e:
    print("Error reading:", e)
