import json
import os
import sys
from datetime import datetime

# Add src to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'src')))

try:
    from core.db_client import SupabaseClient
except ImportError:
    # Try alternate path
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))
    from src.core.db_client import SupabaseClient

def clean_phone(phone):
    if not phone: return ""
    # Keep only digits
    import re
    cleaned = re.sub(r'[^0-9]', '', phone)
    # If it starts with 225 and has 12 digits, or if it has 10 digits add 225
    if len(cleaned) == 10:
        return f"225{cleaned}"
    return cleaned

def import_data(file_path):
    db = SupabaseClient()
    
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    print(f"🚀 Importing {len(data)} jobs from {file_path}...")

    success_count = 0
    error_count = 0

    for item in data:
        try:
            # Map JSON to Database fields
            job_data = {
                "job_title": item.get("title", "Sans titre"),
                "company_name": item.get("nom_entreprise", "Non précisé"),
                "source_url": item.get("lien"),
                "deadline": item.get("deadline"),
                "required_level": item.get("niveau"),
                "description": f"{item.get('description_entreprise', '')}\n\n{item.get('description_poste', '')}".strip(),
                "application_instructions": item.get("dossiers_candidature"),
                "is_ai_verified": True,
                "tags": ["Educarriere"],
                "location": "Abidjan", # Default for Educarriere usually
            }

            # Handle contact info
            contact = item.get("contact", {})
            
            emails = contact.get("emails", [])
            if emails:
                job_data["contact_email"] = emails[0]
            
            phones = contact.get("phones", [])
            if phones:
                job_data["whatsapp_number"] = clean_phone(phones[0])
            
            # Application link and instructions
            app_link = contact.get("urls", [None])[0] if contact.get("urls") else None
            app_instr = item.get("dossiers_candidature")
            
            # Put extra info in raw_data
            job_data["raw_data"] = {
                "application_link": app_link,
                "application_instructions": app_instr
            }
            
            # Also try to add them as columns in case the user added them
            job_data["application_link"] = app_link
            job_data["application_instructions"] = app_instr

            # Insert into database - note that SupabaseClient.insert_job catches exceptions 
            # and returns None, printing the error.
            res = db.insert_job(job_data)
            
            # If it failed due to missing columns, retry without those columns 
            # (The application info is still in raw_data)
            if res is None:
                print(f"⚠️ Retrying without optional columns for {job_data.get('job_title')}...")
                job_data.pop("application_link", None)
                job_data.pop("application_instructions", None)
                # Ensure we also remove other potentially missing columns if needed
                res = db.insert_job(job_data)

            if res:
                success_count += 1
                if success_count % 10 == 0:
                    print(f"✅ Progress: {success_count}/{len(data)} jobs imported.")
            else:
                error_count += 1
        except Exception as e:
            print(f"❌ Error processing job {item.get('title')}: {e}")
            error_count += 1

    print(f"\n🏁 Finished. {success_count} jobs imported, {error_count} errors.")

if __name__ == "__main__":
    FILE_PATH = "/Users/mac/DJORSSI-MATCH/scraper/exaction/offres_educarriere_resume.json"
    import_data(FILE_PATH)
