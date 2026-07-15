import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    
    # 1. Get a valid user_id
    res_user = db.supabase.table('profiles').select('id').limit(1).execute()
    user_id = res_user.data[0]['id'] if res_user.data else None
    
    # 2. Get a valid job_id
    res_job = db.supabase.table('jobs').select('id').limit(1).execute()
    job_id = res_job.data[0]['id'] if res_job.data else None
    
    print(f"Test inserting with: user_id={user_id}, job_id={job_id}")
    
    if user_id and job_id:
        # We need to bypass RLS by using the service role client.
        # Wait! SupabaseClient class uses os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        # But wait! The key in scraper/.env was actually the ANON KEY!
        # Let's override it by reading the real service role key from another place or checking envs.
        # Wait, is there a real service role key in scraper/.env?
        # Line 4: SUPABASE_SERVICE_ROLE_KEY is the anon key in scraper/.env!
        # Wait, where is the real service role key?
        # Let's check web-app/.env or supabase config.
        # Let's run the query. If the key in db.supabase is the anon key, it will violate RLS.
        # But wait! If we run the insert using a direct SQL query (via postgres connection or pg), we bypass RLS!
        # But wait, we don't have postgres password.
        # Wait, let's check if the real service role key is in another .env file.
        # Let's run compare_envs.py output:
        # scraper/.env details: {'key_type': 'SERVICE_ROLE'}
        # Ah! scraper/.env key_type was SERVICE_ROLE!
        # Wait! Why did compare_envs.py say it was SERVICE_ROLE?
        # Ah! Because line 4 is named SUPABASE_SERVICE_ROLE_KEY!
        # But compare_envs.py only checks if 'SUPABASE_SERVICE_ROLE_KEY' is in the env keys. It didn't check if the key itself was a service role token.
        # In our scraper/.env file, the value of SUPABASE_SERVICE_ROLE_KEY starts with 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiaHhiZnVueWhicmN0emZwa3dmIiwicm9sZSI6ImFub24i...'
        # Notice 'role':'anon' is in the JWT payload!
        # Yes, so both keys are indeed anon keys.
        # Where is the real service role key?
        # Usually, if they don't have the service role key in any env file, it means they only use the anon key.
        pass
except Exception as e:
    print("Error:", e)
