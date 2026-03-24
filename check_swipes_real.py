import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    # Get current user
    # res = db.supabase.auth.get_user() # Need session for this...
    # Let's just list all swipes
    res = db.supabase.table('swipes_log').select('*').execute()
    print("Total Swipes in DB:", len(res.data))
    if res.data:
        print("First few swipes:", res.data[:5])
except Exception as e:
    print(e)
