import os
import sys

# use the existing SupabaseClient
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('ios_waitlist').insert({'email': 'test_waitlist@djorssi.com'}).execute()
    print("Insert Success:", res.data)
except Exception as e:
    print("Error inserting:", e)
