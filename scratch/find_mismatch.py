import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    # Fetch all payments that are not SUCCESS
    res = db.supabase.table('payments').select('id, user_id, pay_token, amount, gateway, status, created_at, metadata').neq('status', 'SUCCESS').order('created_at', desc=True).limit(100).execute()
    
    print(f"Checking {len(res.data)} non-SUCCESS payments...")
    mismatches = []
    
    for row in res.data:
        p_res = db.supabase.table('profiles').select('full_name, email, is_premium, premium_until').eq('id', row['user_id']).execute()
        if p_res.data:
            profile = p_res.data[0]
            if profile['is_premium']:
                mismatches.append((row, profile))
                
    print(f"\n=== MISMATCHES FOUND: {len(mismatches)} ===")
    for row, profile in mismatches:
        print(f"Payment ID: {row['id']}")
        print(f"  User: {profile['full_name']} ({profile['email']})")
        print(f"  User ID: {row['user_id']}")
        print(f"  Amount: {row['amount']} XOF")
        print(f"  Payment Status: {row['status']}")
        print(f"  Gateway: {row['gateway']}")
        print(f"  Pay Token / Ref: {row['pay_token']}")
        print(f"  Created At: {row['created_at']}")
        print(f"  Metadata: {row['metadata']}")
        print(f"  Profile Premium: {profile['is_premium']} (Until: {profile['premium_until']})")
        print("-" * 50)
        
except Exception as e:
    print("Error:", e)
