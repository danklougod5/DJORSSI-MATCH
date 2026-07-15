import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    # Simple select
    res = db.supabase.table('payments').select('id', count='exact').execute()
    print("Payments count:", res)
    
    # Let's get raw rows
    res2 = db.supabase.table('payments').select('*').limit(5).execute()
    print("Sample payments:", res2.data)
except Exception as e:
    print("Error:", e)
