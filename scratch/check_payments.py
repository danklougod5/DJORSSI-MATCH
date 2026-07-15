import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    # Fetch all payments in the last few days
    res = db.supabase.table('payments').select('id, user_id, pay_token, amount, gateway, status, created_at, metadata').order('created_at', desc=True).limit(20).execute()
    
    print("=== ALL TRANSACTIONS (LAST 20) ===")
    for row in res.data:
        # Fetch profile
        p_res = db.supabase.table('profiles').select('full_name, email, is_premium, premium_until').eq('id', row['user_id']).execute()
        profile = p_res.data[0] if p_res.data else None
        
        print(f"ID: {row['id']}")
        print(f"  User: {profile['full_name'] if profile else 'Unknown'} ({profile['email'] if profile else 'N/A'})")
        print(f"  User ID: {row['user_id']}")
        print(f"  Amount: {row['amount']} XOF")
        print(f"  Status: {row['status']}")
        print(f"  Gateway: {row['gateway']}")
        print(f"  Pay Token: {row['pay_token']}")
        print(f"  Created At: {row['created_at']}")
        print(f"  Metadata: {row['metadata']}")
        print(f"  Profile Premium: {profile['is_premium'] if profile else 'N/A'} (Until: {profile['premium_until'] if profile else 'N/A'})")
        print("-" * 50)
        
except Exception as e:
    print("Error:", e)
