
import os
import re
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv('c:/Users/HP/Desktop/NEW APP/scraper/.env')

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

supabase: Client = create_client(url, key)

# Get all jobs with suspicious emails
response = supabase.table("jobs").select("id, job_title, contact_email").execute()
all_jobs = response.data

invalid_ids = []
for job in all_jobs:
    email = str(job.get('contact_email', '')).lower()
    if 'protect' in email or '[email' in email or '#' in email:
        print(f"To delete: {job['id']} | {job['job_title']} | {email}")
        invalid_ids.append(job['id'])

if invalid_ids:
    print(f"Deleting {len(invalid_ids)} jobs...")
    # Delete in batches of 10 to be safe
    for i in range(0, len(invalid_ids), 10):
        batch = invalid_ids[i:i+10]
        supabase.table("jobs").delete().in_("id", batch).execute()
        print(f"Deleted batch {i//10 + 1}")
    print("Cleanup complete.")
else:
    print("No invalid jobs found.")
