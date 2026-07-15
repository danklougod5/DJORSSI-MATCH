import sys
import os
import re

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

def extract_phone_numbers(raw):
    if not raw:
        return []
    numbers = []
    cleaned = re.sub(r'[\s\-.\(\)]+', '', raw)
    digit_blocks = re.findall(r'\d+', cleaned)
    
    for digits in digit_blocks:
        remaining = digits
        while remaining:
            if remaining.startswith('225'):
                if len(remaining) >= 13:
                    numbers.append(remaining[:13])
                    remaining = remaining[13:]
                elif len(remaining) >= 11:
                    numbers.append(remaining[:11])
                    remaining = remaining[11:]
                else:
                    if len(remaining) >= 8:
                        numbers.append(remaining)
                    remaining = ''
            else:
                if len(remaining) >= 10:
                    numbers.append(remaining[:10])
                    remaining = remaining[10:]
                elif len(remaining) >= 8:
                    numbers.append(remaining)
                    remaining = ''
                else:
                    remaining = ''
    return numbers

def format_whatsapp_numbers(numbers):
    formatted = []
    for num in numbers:
        if len(num) <= 10:
            # Prepend CI code if missing
            if len(num) == 8:
                formatted.append(f"22507{num}")  # fallback for old 8-digit
            else:
                formatted.append(f"225{num}")
        else:
            formatted.append(num)
    return " / ".join(formatted)

try:
    db = SupabaseClient()
    res = db.supabase.table('jobs').select('id, job_title, whatsapp_number, company_name').neq('whatsapp_number', '').execute()
    
    print(f"🚀 Found {len(res.data)} jobs with WhatsApp numbers. Starting cleaning...")
    
    updated_count = 0
    for job in res.data:
        raw_num = job['whatsapp_number']
        if not raw_num:
            continue
            
        extracted = extract_phone_numbers(raw_num)
        if not extracted:
            # If no numbers could be extracted, clear the field to avoid broken links
            cleaned_val = ""
        else:
            cleaned_val = format_whatsapp_numbers(extracted)
            
        if cleaned_val != raw_num:
            print(f"✏️ Updating job {job['id']} ({job['job_title']} - {job['company_name']}):")
            print(f"    Before: '{raw_num}'")
            print(f"    After:  '{cleaned_val}'")
            
            db.supabase.table('jobs').update({'whatsapp_number': cleaned_val}).eq('id', job['id']).execute()
            updated_count += 1
            print("-" * 50)
            
    print(f"🏁 Finished! Successfully cleaned and updated {updated_count} job offers in the database.")

except Exception as e:
    print("Error:", e)
