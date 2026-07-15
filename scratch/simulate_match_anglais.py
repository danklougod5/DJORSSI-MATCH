import sys
import os
import re
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

# Emulation of swipe_screen.dart matching logic in Python

def normalize_key(tag):
    return tag.lower().strip()

# Removed anglais, francais, allemand, bilingue from genericTags
generic_tags = {'urgent', 'nouveau', 'premium', 'fodese'}

def is_generic_tag(tag):
    return normalize_key(tag) in generic_tags

contract_types = {'cdd', 'cdi', 'stage', 'freelance', 'intérim', 'alternance'}
def is_contract_type(tag):
    return normalize_key(tag) in contract_types

def match_word(text, word):
    text_lower = text.lower()
    word_lower = normalize_key(word)
    if not word_lower:
        return False
    if len(word_lower) <= 4:
        escaped = re.escape(word_lower)
        pattern = r'\b' + escaped + r'\b'
        return bool(re.search(pattern, text_lower))
    return word_lower in text_lower

def calculate_match_score(job, user_skills, is_premium=True):
    if not user_skills:
        return 50
        
    total_score = 0.0
    matches_count = 0
    
    has_sector_skills = any(
        not is_contract_type(s) and not is_generic_tag(s) for s in user_skills
    )
    matched_sector_skill = False
    
    job_title = job.get('job_title', '').lower().strip()
    job_specialty = job.get('specialty', '')
    if job_specialty is None:
        job_specialty = ''
    job_specialty = job_specialty.lower().strip()
    
    job_description = job.get('description', '').lower()
    
    raw_tags = job.get('tags') or []
    all_job_tags = [t.lower().strip() for t in raw_tags]
    
    for skill in user_skills:
        current_skill_score = 0.0
        skill_lower = skill.lower().strip()
        is_contract_tag = is_contract_type(skill_lower)
        is_sector_skill = not is_contract_tag and not is_generic_tag(skill_lower)
        
        matched_this_skill = False
        
        # 1. Match direct par tag
        for job_tag in all_job_tags:
            if normalize_key(job_tag) == normalize_key(skill_lower):
                current_skill_score += 400 if is_contract_tag else 300
                matched_this_skill = True
                break
            if len(skill_lower) > 3 and (normalize_key(skill_lower) in normalize_key(job_tag) or normalize_key(job_tag) in normalize_key(skill_lower)):
                current_skill_score += 150
                matched_this_skill = True
                break
                
        # 2. Match par spécialité
        if not matched_this_skill and job_specialty:
            if normalize_key(job_specialty) == normalize_key(skill_lower):
                current_skill_score += 150
                matched_this_skill = True
            elif len(skill_lower) > 3 and (normalize_key(skill_lower) in normalize_key(job_specialty) or normalize_key(job_specialty) in normalize_key(skill_lower)):
                current_skill_score += 80
                matched_this_skill = True
                
        # 3. Match par mot clé (en étendant)
        # For simplicity, we just use direct match_word for title/tags since tagFamilies don't contain anglais
        if not matched_this_skill:
            # We don't have getExpandedKeywords, but for 'Anglais' it just returns ['anglais']
            expanded = [skill_lower]
            for kw in expanded:
                kw_lower = kw.lower().strip()
                if match_word(job_title, kw_lower):
                    current_skill_score += 100
                    matched_this_skill = True
                    break
                if any(match_word(tag, kw_lower) for tag in all_job_tags):
                    current_skill_score += 50
                    matched_this_skill = True
                    break
                    
        # 4. Match par description
        if not matched_this_skill or is_contract_tag:
            if match_word(job_description, skill_lower):
                current_skill_score += 20 if matched_this_skill else 40
                matched_this_skill = True
                
        if matched_this_skill:
            total_score += current_skill_score
            matches_count += 1
            if is_sector_skill:
                matched_sector_skill = True
                
    if matches_count == 0 and user_skills:
        return -100
        
    if has_sector_skills and not matched_sector_skill:
        return -100
        
    if matches_count > 1:
        total_score += matches_count * 30
        
    # premium bonus
    if is_premium:
        # just assume some bonus
        total_score += 50
        
    return int(min(max(total_score, 0), 1000))

try:
    db = SupabaseClient()
    res = db.supabase.table('jobs').select('id, job_title, tags, description, created_at, is_approved').eq('is_approved', True).order('created_at', desc=True).limit(50).execute()
    jobs = res.data
    
    print(f"Loaded {len(jobs)} recent approved jobs.")
    user_skills = ["Anglais"]
    
    matched = 0
    for i, job in enumerate(jobs):
        score = calculate_match_score(job, user_skills, is_premium=True)
        title = job.get('job_title')
        tags = job.get('tags')
        if score > 0:
            matched += 1
            print(f"Job #{i+1} [Score: {score}]: ID: {job['id']} | Title: {title} | Tags: {tags}")
            
    print(f"\nTotal jobs with score > 0: {matched} / 50")
    
except Exception as e:
    print("Error:", e)
