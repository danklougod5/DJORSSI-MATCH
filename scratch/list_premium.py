import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    res = db.supabase.table('profiles').select('id, full_name, email, is_premium, premium_until, created_at').eq('is_premium', True).execute()
    print(f"Total premium profiles in DB: {len(res.data)}")
    for p in res.data:
        print(f"ID: {p['id']}")
        print(f"  Name: {p['full_name']}")
        print(f"  Email: {p['email']}")
        print(f"  Premium: {p['is_premium']}")
        print(f"  Premium Until: {p['premium_until']}")
        print(f"  Created At: {p['created_at']}")
        print("-" * 50)
except Exception as e:
    print("Error:", e)
