import os
import urllib.request
import json
from dotenv import load_dotenv

load_dotenv("app/.env")

url = os.environ.get("SUPABASE_URL") or os.environ.get("VAR_SUPABASE_URL")
key = os.environ.get("SUPABASE_ANON_KEY") or os.environ.get("VAR_SUPABASE_ANON_KEY")

if not url:
    url = "https://tbhxbfunyhbrctzfpkwf.supabase.co"
if not key:
    with open("app/.env") as f:
        for line in f:
            if 'SUPABASE_ANON_KEY' in line or 'VAR_SUPABASE_ANON_KEY' in line:
                key = line.split('=', 1)[1].strip().strip('"').strip("'")

function_url = f"{url}/functions/v1/reconcile-payments"

req = urllib.request.Request(
    function_url,
    headers={
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(req) as response:
        body = response.read().decode("utf-8")
        parsed = json.loads(body)
        print(json.dumps(parsed, indent=2))
except urllib.error.HTTPError as e:
    print(f"HTTP Error {e.code}:")
    print(e.read().decode("utf-8"))
except Exception as e:
    print("Error:", e)
