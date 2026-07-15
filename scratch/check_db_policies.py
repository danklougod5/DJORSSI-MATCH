import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    # We can query postgres pg_policies via a simple select (sometimes accessible, sometimes not, but let's try)
    res = db.supabase.table('profiles').select('*').limit(1).execute()
    # Let's try to query pg_policies using custom select
    res_pol = db.supabase.rpc('get_policies', {'table_name': 'swipes_log'}).execute()
    print("Policies via RPC:", res_pol.data)
except Exception as e:
    print("Error querying policies:", e)
