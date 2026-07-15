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

print("--- 1. Premium Profiles ---")
res_profiles = supabase.from_('profiles').select('id, full_name, is_premium, premium_until, fcm_token').eq('is_premium', True).execute()
for p in res_profiles.data:
    print(f"ID: {p['id']}, Name: {p.get('full_name')}, Premium: {p.get('is_premium')}, FCM Token: {p.get('fcm_token') is not None}")

print("\n--- 2. Active Job Alerts ---")
res_alerts = supabase.from_('job_alerts').select('id, user_id, sectors, is_active').eq('is_active', True).execute()
for a in res_alerts.data:
    print(f"Alert ID: {a['id']}, User ID: {a['user_id']}, Sectors: {a['sectors']}, Active: {a['is_active']}")

print("\n--- 3. Jobs (Recent 5) ---")
res_jobs = supabase.from_('jobs').select('id, job_title, tags, company_name').order('created_at', desc=True).limit(5).execute()
for j in res_jobs.data:
    print(f"Job ID: {j['id']}, Title: {j['job_title']}, Tags: {j['tags']}, Company: {j['company_name']}")
