import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# Config
url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    print("[ERROR] Database credentials missing in .env")
    exit(1)

try:
    supabase: Client = create_client(url, key)
    print(f"[INFO] Nettoyage en cours sur {url}...")
    
    # On supprime toutes les offres actuelles (TOUT supprimer)
    # n.b. delete().neq() avec un UUID inexistant est le moyen standard Supabase de dire 'TOUT supprimer'
    response = supabase.table("jobs").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
    
    print(f"[OK] Base de données vidée avec succès !")
    print(f"[OK] Offres supprimées.")
    
except Exception as e:
    print(f"[ERROR] Échec du nettoyage : {e}")
