import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    
    # Query all users with right swipes in swipes_log
    res_swipes = db.supabase.table('swipes_log').select('user_id', 'direction').eq('direction', 'right').execute()
    swiping_user_ids = list(set([s['user_id'] for s in res_swipes.data]))
    
    print(f"Total unique users who swiped right: {len(swiping_user_ids)}")
    
    # Query their profiles
    if swiping_user_ids:
        # Supabase in query: we can do a loop or in filter
        res_profiles = db.supabase.table('profiles').select('id', 'full_name', 'cv_url').in_('id', swiping_user_ids).execute()
        
        profiles_by_id = {p['id']: p for p in res_profiles.data}
        
        no_cv_swipers = []
        for uid in swiping_user_ids:
            p = profiles_by_id.get(uid)
            if not p:
                print(f"User {uid} swiped right but has no profile record!")
                continue
            
            cv_url = p.get('cv_url')
            if not cv_url or cv_url.strip() == "" or cv_url.lower() in ["null", "undefined"]:
                no_cv_swipers.append(p)
        
        print(f"Users who swiped right but have no valid CV in profile: {len(no_cv_swipers)}")
        for p in no_cv_swipers[:20]:
            print(f"- Name: {p['full_name']} | ID: {p['id']} | cv_url: {p['cv_url']}")
            
            # Let's count how many swipes this user has
            res_user_swipes = db.supabase.table('swipes_log').select('id', count='exact').eq('user_id', p['id']).eq('direction', 'right').execute()
            print(f"  Swipes count: {len(res_user_swipes.data)}")
            
except Exception as e:
    print("Error:", e)
