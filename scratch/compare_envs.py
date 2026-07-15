import os
from dotenv import load_dotenv

def get_env_details(path):
    if not os.path.exists(path):
        return f"File {path} not found"
    # Load env
    env_vars = {}
    with open(path) as f:
        for line in f:
            if '=' in line and not line.strip().startswith('#'):
                k, v = line.strip().split('=', 1)
                env_vars[k.strip()] = v.strip().strip('"').strip("'")
    
    url = env_vars.get('SUPABASE_URL') or env_vars.get('VITE_SUPABASE_URL')
    key = env_vars.get('SUPABASE_SERVICE_ROLE_KEY') or env_vars.get('SUPABASE_ANON_KEY') or env_vars.get('VITE_SUPABASE_ANON_KEY')
    key_type = 'SERVICE_ROLE' if 'SUPABASE_SERVICE_ROLE_KEY' in env_vars else 'ANON'
    
    return {
        'url': url,
        'key_len': len(key) if key else 0,
        'key_start': key[:10] if key else 'None',
        'key_type': key_type
    }

print("scraper/.env details:", get_env_details('scraper/.env'))
print("web-app/.env details:", get_env_details('web-app/.env'))
print("app/.env details:", get_env_details('app/.env'))
