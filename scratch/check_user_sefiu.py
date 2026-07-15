import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv("app/.env")

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")

if not url or not key:
    print("Missing env vars")
    exit(1)

supabase: Client = create_client(url, key)

# 1. Search for user Sefiu
print("=" * 60)
print("RECHERCHE UTILISATEUR: Sefiu Nurudeen")
print("=" * 60)

res = supabase.from_('profiles').select(
    'id, full_name, phone_number, is_premium, premium_until, created_at, updated_at'
).ilike('full_name', '%sefiu%').execute()

if not res.data:
    res = supabase.from_('profiles').select(
        'id, full_name, phone_number, is_premium, premium_until, created_at, updated_at'
    ).ilike('full_name', '%nurudeen%').execute()

if not res.data:
    print("❌ Aucun utilisateur trouvé")
    exit(0)

for p in res.data:
    user_id = p['id']
    print(f"\n👤 Profil:")
    print(f"   ID: {user_id}")
    print(f"   Nom: {p.get('full_name')}")
    print(f"   Téléphone: {p.get('phone_number')}")
    print(f"   Premium: {p.get('is_premium')}")
    print(f"   Premium jusqu'au: {p.get('premium_until')}")
    print(f"   Mis à jour: {p.get('updated_at')}")

    # Check payments
    pay_res = supabase.from_('payments').select('*').eq('user_id', user_id).order('created_at', desc=True).execute()
    if not pay_res.data:
        print(f"   💳 Paiements: ❌ Aucun")
    else:
        for pay in pay_res.data:
            print(f"   💳 Paiement: {pay.get('amount')} {pay.get('currency')} | Statut: {pay.get('status')} | Gateway: {pay.get('gateway')} | Token: {pay.get('pay_token')} | Créé: {pay.get('created_at')}")

# 2. Check ALL payments in DB
print("\n" + "=" * 60)
print("TOUS LES PAIEMENTS DANS LA BASE (derniers 20)")
print("=" * 60)

all_pay = supabase.from_('payments').select(
    'id, user_id, pay_token, amount, currency, gateway, status, description, metadata, created_at'
).order('created_at', desc=True).limit(20).execute()

if not all_pay.data:
    print("❌ Table payments toujours vide")
else:
    for pay in all_pay.data:
        print(f"\n   User: {pay.get('user_id')} | {pay.get('amount')} {pay.get('currency')} | {pay.get('status')} | {pay.get('gateway')} | Token: {pay.get('pay_token')} | {pay.get('created_at')}")

print("\n" + "=" * 60)
