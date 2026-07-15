import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    # Fetch profiles updated recently or with premium_until set recently
    res = db.supabase.table('profiles').select('id, full_name, email, is_premium, premium_until, created_at, updated_at').eq('is_premium', True).execute()
    
    print("=== PREMIUM PROFILES ===")
    for p in res.data:
        # Check their payments
        pay_res = db.supabase.table('payments').select('id, amount, status, gateway, pay_token, created_at').eq('user_id', p['id']).execute()
        
        print(f"User: {p['full_name']} ({p['email']}) | ID: {p['id']}")
        print(f"  Premium Until: {p['premium_until']}")
        print(f"  Created At: {p['created_at']}")
        print(f"  Payments:")
        if pay_res.data:
            for pay in pay_res.data:
                print(f"    - Token: {pay['pay_token']} | Amount: {pay['amount']} | Status: {pay['status']} | Created: {pay['created_at']}")
        else:
            print("    No payments found in payments table")
        print("-" * 50)
except Exception as e:
    print("Error:", e)
