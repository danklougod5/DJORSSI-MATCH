import json
import os
import sys
import re
from datetime import datetime
from dotenv import load_dotenv

# Add src to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'src')))

try:
    from core.db_client import SupabaseClient
    from supabase import create_client, Client
except ImportError:
    # Try alternate path
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))
    from src.core.db_client import SupabaseClient
    from supabase import create_client, Client

load_dotenv()

def clean_phone(phone):
    if not phone: return ""
    # Keep only digits
    cleaned = re.sub(r'[^0-9]', '', str(phone))
    # If it starts with 225 and has 12 digits, or if it has 10 digits add 225
    if len(cleaned) == 10:
        return f"225{cleaned}"
    elif len(cleaned) == 8: # some old numbers
        return f"22507{cleaned}" # guessing 07 for old 8-digit numbers? maybe better not to guess or use 225
    return cleaned

def reimport_data(file_path):
    # Initialize DB client
    db_wrapper = SupabaseClient()
    if not db_wrapper.supabase:
        print("❌ Error: Supabase client not initialized. Check your .env file.")
        return

    supabase = db_wrapper.supabase

    # 1. Clean the database
    print(f"🧹 Nettoyage de la table 'jobs'...")
    try:
        # Standard way to delete all rows in Supabase
        supabase.table("jobs").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        print("✅ Table 'jobs' vidée avec succès.")
    except Exception as e:
        print(f"❌ Erreur lors du nettoyage : {e}")
        return

    # 2. Load JSON data
    if not os.path.exists(file_path):
        print(f"❌ Fichier non trouvé : {file_path}")
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    print(f"🚀 Importation de {len(data)} offres depuis {file_path}...")

    success_count = 0
    error_count = 0

    for i, item in enumerate(data):
        try:
            # Map JSON to Database fields
            # Generate a source_url if it's missing (needed for unique constraint/upsert logic)
            source_url = item.get("urls")
            if not source_url:
                source_url = f"extraction1_id_{i}"

            job_data = {
                "job_title": item.get("title", "Sans titre"),
                "company_name": item.get("company_name") or "Non précisé",
                "description": item.get("summary", ""),
                "deadline": item.get("deadline"),
                "required_level": item.get("niveau"),
                "location": item.get("lieu", "Côte d'Ivoire"),
                "source_url": source_url,
                "is_ai_verified": True,
                "tags": item.get("tags", []),
                "contact_email": item.get("email"),
                "whatsapp_number": clean_phone(item.get("contact")),
                "application_instructions": item.get("objet"),
                "application_link": item.get("urls"),
                "requires_cover_letter": item.get("lettre_motivation") is not None and str(item.get("lettre_motivation")).upper() != "NON",
                "cover_letter_instructions": item.get("lettre_motivation"),
                "raw_data": item
            }

            # Insert into database
            res = db_wrapper.insert_job(job_data)
            
            if res:
                success_count += 1
                if success_count % 10 == 0:
                    print(f"✅ Progrès : {success_count}/{len(data)} offres importées.")
            else:
                # If it failed, maybe some columns are missing
                # Try a safer insert with only base columns
                safe_data = {
                    "job_title": job_data["job_title"],
                    "company_name": job_data["company_name"],
                    "description": job_data["description"],
                    "deadline": job_data["deadline"],
                    "required_level": job_data["required_level"],
                    "location": job_data["location"],
                    "source_url": job_data["source_url"],
                    "is_ai_verified": True,
                    "tags": job_data["tags"],
                    "raw_data": job_data["raw_data"]
                }
                res = db_wrapper.insert_job(safe_data)
                if res:
                    success_count += 1
                else:
                    error_count += 1
                    print(f"❌ Échec pour : {job_data['job_title']}")
        except Exception as e:
            print(f"❌ Erreur lors du traitement de l'offre {i}: {e}")
            error_count += 1

    print(f"\n🏁 Terminé. {success_count} offres importées, {error_count} erreurs.")

if __name__ == "__main__":
    # Note the space in the filename provided by the user
    FILE_PATH = "/Users/mac/DJORSSI-MATCH/scraper/exaction/extraction1 .json"
    reimport_data(FILE_PATH)
