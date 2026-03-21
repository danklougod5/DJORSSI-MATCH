import json
import asyncio
import os
import sys
from datetime import datetime

# Add src to path if needed
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))

from src.core.ai_validator import AIJobValidator

def clean_text(text):
    """Décode les emails protégés par Cloudflare [email protected]"""
    import re
    if not text: return ""
    protected_emails = re.findall(r'email-protection#([a-fA-F0-9]+)', text)
    for hex_val in protected_emails:
        try:
            k = int(hex_val[:2], 16)
            real_email = "".join([chr(int(hex_val[i:i+2], 16) ^ k) for i in range(2, len(hex_val), 2)])
            if real_email:
                text = text.replace(f"email-protection#{hex_val}", real_email)
        except: pass
    # Nettoyage additionnel pour les chaînes [email protected] statiques
    text = text.replace("[email\u00a0protected]", "[email protected]")
    return text

async def process_manual_extraction(file_path, limit=5):
    validator = AIJobValidator()
    # db = SupabaseClient()
    
    if not os.path.exists(file_path):
        print(f"❌ Fichier non trouvé : {file_path}")
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    print(f"📦 Traitement des {min(limit, len(data))} premières offres sur {len(data)}...")

    results = []
    for i, item in enumerate(data[:limit]):
        # On regroupe tous les champs du JSON pour donner le maximum de contexte à l'IA
        # On nettoie et TRONQUE le texte pour gagner en vitesse (7b est lent)
        title = clean_text(item.get('title', ''))[:200]
        # On limite la description de l'entreprise qui est souvent très longue
        company_desc = clean_text(item.get('col-xl-9 (2)', ''))[:1000]
        # On limite aussi la description du poste
        job_desc = clean_text(item.get('col-xl-9 (4)', ''))[:1500]
        
        deadline_raw = clean_text(item.get('list-group-item (2)', ''))
        location_raw = clean_text(item.get('list-group-item (4)', ''))
        experience_raw = clean_text(item.get('list-group-item (5)', ''))
        level_raw = clean_text(item.get('list-group-item (6)', ''))
        contact_raw = clean_text(item.get('col-xl-9 (6)', ''))
        source_url = item.get('post-img href', '')

        # Version turbo : on envoie que l'essentiel
        raw_text = f"TITRE: {title}\nLIEU: {location_raw}\nDEADLINE: {deadline_raw}\nNIVEAU: {level_raw}\nCONTACT: {contact_raw}\nDESC: {job_desc}\nCORP: {company_desc}"
        
        print(f"\n--- [{i+1}/{limit}] ANALYSE DE : {item.get('title', 'Sans titre')} ---")
        
        # Appel à Ollama via le validateur existant
        cleaned_data = await validator.validate_and_clean_job(raw_text)
        
        if cleaned_data:
            if cleaned_data.get("is_job"):
                cleaned_data["source_url"] = item.get('post-img href')
                print(f"✅ VALIDE")
                print(f"   Titre: {cleaned_data.get('job_title')}")
                print(f"   Entreprise: {cleaned_data.get('company_name')}")
                print(f"   Lieu: {cleaned_data.get('location')}")
                print(f"   Deadline: {cleaned_data.get('deadline')}")
                print(f"   Email: {cleaned_data.get('contact_email')}")
                print(f"   WhatsApp: {cleaned_data.get('whatsapp_number')}")
                results.append(cleaned_data)
            else:
                print(f"❌ REJETÉ par l'IA (Pas de contact valide ou pas une offre réelle)")
        else:
            print(f"⚠️ Erreur de réponse de l'IA")

    print(f"\n🏁 TEST TERMINÉ. {len(results)}/{limit} offres validées.")
    return results

if __name__ == "__main__":
    # Chemin vers votre fichier JSON
    FILE_PATH = "/Users/mac/DJORSSI-MATCH/scraper/exaction/Extraire-des-détails-de-educarriere.ci--1--2026-03-20.json"
    
    try:
        asyncio.run(process_manual_extraction(FILE_PATH, limit=5))
    except KeyboardInterrupt:
        print("\nArrêt du script.")
    except Exception as e:
        print(f"\nCRITICAL ERROR: {repr(e)}")
