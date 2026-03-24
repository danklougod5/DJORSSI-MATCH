import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# Config
url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    print("[ERROR] Database configuration missing in .env")
    exit(1)

try:
    supabase: Client = create_client(url, key)
    # Mask URL to avoid exposing project ID in logs
    masked_url = f"{url[:12]}...{url[-10:]}" if len(url) > 22 else url
    print(f"[INFO] Nettoyage en cours sur {masked_url}...")
    
    # On supprime toutes les offres actuelles (TOUT supprimer)
    # n.b. delete().neq() avec un UUID inexistant est le moyen standard Supabase de dire 'TOUT supprimer'
    response = supabase.table("jobs").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
    
    print(f"[OK] Base de données vidée avec succès !")
    print(f"[OK] Offres supprimées.")
    
except Exception as e:
    print(f"[ERROR] Échec du nettoyage : {e}")
