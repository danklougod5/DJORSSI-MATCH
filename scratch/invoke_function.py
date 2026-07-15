import os
import json
import urllib.request
from dotenv import load_dotenv

load_dotenv("app/.env")

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")

if not url or not key:
    print("Missing env vars")
    exit(1)

function_url = f"{url}/functions/v1/notify-job-alerts"

headers = {
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json"
}

from supabase import create_client
supabase = create_client(url, key)
res_jobs = supabase.from_('jobs').select('id, tags').order('created_at', desc=True).limit(1).execute()
if not res_jobs.data:
    print("No jobs found")
    exit(1)

job_id = res_jobs.data[0]['id']
print(f"Triggering for job {job_id}...")

payload = json.dumps({"job_id": job_id}).encode("utf-8")
req = urllib.request.Request(function_url, data=payload, headers=headers, method="POST")

try:
    with urllib.request.urlopen(req) as response:
        print(f"Status: {response.status}")
        resp_body = response.read().decode("utf-8")
        print("Response JSON:")
        print(resp_body)
except urllib.error.HTTPError as e:
    print(f"HTTPError: {e.code}")
    print(e.read().decode("utf-8"))
except Exception as e:
    print(f"Error: {e}")
