import os

def check_env(path):
    env_vars = {}
    with open(path) as f:
        for line in f:
            if '=' in line and not line.strip().startswith('#'):
                k, v = line.strip().split('=', 1)
                env_vars[k.strip()] = v.strip().strip('"').strip("'")
    
    anon = env_vars.get('SUPABASE_ANON_KEY') or env_vars.get('VITE_SUPABASE_ANON_KEY')
    service = env_vars.get('SUPABASE_SERVICE_ROLE_KEY')
    
    print(f"File: {path}")
    print(f"  Anon Key: {anon[:15]}... (len: {len(anon) if anon else 0})")
    print(f"  Service Role Key: {service[:15]}... (len: {len(service) if service else 0})")
    print(f"  Are they identical? {anon == service}")

check_env('scraper/.env')
