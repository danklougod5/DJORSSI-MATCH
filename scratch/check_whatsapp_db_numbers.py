import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    # Query all jobs with a non-empty whatsapp_number
    res = db.supabase.table('jobs').select('id, job_title, whatsapp_number, company_name, created_at').neq('whatsapp_number', '').execute()
    
    print(f"=== CHECKING WHATSAPP NUMBERS IN DATABASE (Total: {len(res.data)}) ===")
    
    malformed_count = 0
    for job in res.data:
        num = job['whatsapp_number']
        # Check if the number does not start with 225 or doesn't have a valid length
        is_malformed = False
        reason = ""
        
        if not num:
            continue
            
        if not num.startswith('225'):
            is_malformed = True
            reason = "Doesn't start with country code 225"
        elif len(num) != 13: # standard 225 + 10 digits
            if len(num) == 11:
                # Old format with 225 + 8 digits (valid but old)
                pass
            else:
                is_malformed = True
                reason = f"Invalid length: {len(num)} chars (value: {num})"
        
        if is_malformed:
            malformed_count += 1
            print(f"Job ID: {job['id']} | Title: {job['job_title']} | Company: {job['company_name']}")
            print(f"  Number: {num}")
            print(f"  Reason: {reason}")
            print("-" * 50)
            
    print(f"Total malformed numbers found: {malformed_count} / {len(res.data)}")
except Exception as e:
    print("Error:", e)
