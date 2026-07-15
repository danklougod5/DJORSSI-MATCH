import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    # Query database for column names of swipes_log
    res = db.supabase.rpc('get_table_columns', {'table_name': 'swipes_log'}).execute()
    print("Columns via RPC:", res.data)
except Exception as e:
    print("RPC failed, trying raw query...")
    
try:
    db = SupabaseClient()
    res = db.supabase.table('jobs').select('id').limit(1).execute()
    job_id = res.data[0]['id'] if res.data else None
    print("Found a test job_id:", job_id)
    
    # Let's try to query information_schema if possible (might fail due to permissions, but let's try)
    # Actually, we can just look at swipes_log columns using postgrest by doing a select with non-existent column
    # and reading the error hint/message, or by inserting a dummy row and reading the error message.
    # Let's try inserting a dummy row with a fake user_id and see what error we get.
    dummy_user_id = '00000000-0000-0000-0000-000000000000'
    res_ins = db.supabase.table('swipes_log').insert({
        'user_id': dummy_user_id,
        'job_id': job_id,
        'direction': 'left'
    }).execute()
    print("Insert result:", res_ins.data)
except Exception as e:
    print("Error during insert test:", e)
