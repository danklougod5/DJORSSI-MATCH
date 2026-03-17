"""
Djossi Match - Full Auto Scraper
Scrapes ALL major job sites for Cote d'Ivoire every 5 minutes.

Sources:
  1. Google Jobs (via SerpApi)
  2. jobivoire.ci
  3. educarriere.ci
  4. emploi.ci (Stealth)
  5. rmo-jobcenter.com
  6. projobivoire.com
  7. Google Web Search
"""
import sys
print("BOOTING...", flush=True)

import os
import sys
import time
from datetime import datetime
import json
from src.core.db_client import SupabaseClient
from src.core.ai_validator import AIJobValidator
from src.crawlers.jobivoire import scrape_jobivoire
from src.crawlers.educarriere import scrape_educarriere
from src.crawlers.emploici import scrape_emploici
from src.crawlers.rmo import scrape_rmo
from src.crawlers.projobivoire import scrape_projobivoire
from src.crawlers.google_jobs import scrape_google_jobs
from src.crawlers.google_search import scrape_google_search
from src.crawlers.rss_feeds import scrape_rss_feeds
from src.crawlers.adzuna import scrape_adzuna
print("IMPORTS DONE.", flush=True)


REFRESH_INTERVAL = 900  # 15 minutes to save quota
MAX_JOBS_PER_CYCLE = 10 # Limit AI calls per cycle
STATE_FILE = "scraper_state.json"

def load_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_state(state):
    try:
        with open(STATE_FILE, 'w') as f:
            json.dump(state, f)
    except Exception as e:
        print(f"[WARN] Could not save state: {e}")

def process_and_store(jobs: list[dict], db: SupabaseClient, validator: AIJobValidator):
    """Takes a list of raw scraped jobs, validates them via AI, and inserts into Supabase."""
    success_count = 0
    skip_count = 0
    
    import re
    # Simple regex to check for email or phone before calling expensive AI
    EMAIL_REGEX = r'[a-zA-Z0-9._%+-]+@(?!(?:email-protection|protected))[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    PHONE_REGEX = r'\+?[0-9]{8,15}'
    
    def clean_text(text):
        # Remove Cloudflare and other script placeholders
        text = re.sub(r'\[email\s+protected\]', '', text, flags=re.IGNORECASE)
        text = re.sub(r'email-protection#[a-fA-F0-9]+', '', text, flags=re.IGNORECASE)
        text = re.sub(r'Cette adresse e-mail est protégée contre les robots.*?\.', '', text, flags=re.IGNORECASE)
        return text

    for i, job in enumerate(jobs):
        if success_count >= MAX_JOBS_PER_CYCLE:
            print(f"\n[INFO] Reached limit of {MAX_JOBS_PER_CYCLE} jobs for this cycle. Stopping to save quota.")
            break

        print(f"\n[{i+1}/{len(jobs)}] Processing: {job['source_url'][:65]}...", flush=True)
        
        # PRE-FILTER: Check if contact info exists in raw text
        raw_text = clean_text(job["raw_text"])
        has_email = re.search(EMAIL_REGEX, raw_text)
        has_phone = re.search(PHONE_REGEX, raw_text)
        
        if not has_email and not has_phone:
            print(f"  [PRE-SKIP] No REAL email or phone detected in raw text. Saving AI quota.")
            skip_count += 1
            continue

        job_data = validator.validate_and_clean_job(raw_text)
        
        if not job_data or not job_data.get("job_title") or not job_data.get("contact_email"):
            print(f"  [SKIP] Invalid job, missing title or contact email.")
            skip_count += 1
            continue
        
        job_data.pop("is_job", None)
        job_data.pop("contract_type", None)
        job_data.pop("specialty", None)
        job_data["source_url"] = job["source_url"]
        
        result = db.insert_job(job_data)
        if result:
            print(f"  [OK] Inserted: {job_data.get('job_title')} @ {job_data.get('company_name')}", flush=True)
            success_count += 1
        else:
            print(f"  [WARN] Insert failed or duplicate.", flush=True)
            skip_count += 1
        
        time.sleep(1)  # Faster now with DeepSeek fallback handling 429s
    
    return success_count, skip_count


def scrape_source(name, scrape_fn, db, validator, totals, state_page=1):
    """Safely scrape a single source and process results."""
    try:
        jobs = scrape_fn(state_page) if getattr(scrape_fn, '__code__', None) and scrape_fn.__code__.co_argcount > 0 else scrape_fn()
        if not jobs:
            print(f"  {name}: 0 jobs collected.", flush=True)
            return 0
        
        print(f"  {name}: {len(jobs)} raw jobs collected.", flush=True)
        s, sk = process_and_store(jobs, db, validator)
        totals[0] += s
        totals[1] += sk
        return len(jobs)
    except Exception as e:
        print(f"  [ERROR] {name} failed: {e}", flush=True)
        return 0


def main():
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print("\n" + "=" * 60, flush=True)
    print(f"START: Djossi Match Full Scraper | {now}", flush=True)
    print("=" * 60, flush=True)
    
    db = SupabaseClient()
    validator = AIJobValidator()
    
    if not db.supabase or not validator.providers:
        print("[ERROR] Critical initialization failed. Check .env file. Exiting.", flush=True)
        sys.exit(1)
    
    totals = [0, 0]  # [success, skip]
    state = load_state()
    
    # Sources list definition. 
    # For paginated ones, we fetch pages=[1, p] where p is from state.
    sources = [
        ("Source 0: Google Jobs (SerpApi)",  lambda p: scrape_google_jobs(page=p), True),
        ("Source 1: jobivoire.ci",           lambda p: scrape_jobivoire(pages=[1, p]) if p > 1 else scrape_jobivoire(pages=[1]), True),
        ("Source 2: educarriere.ci",         lambda p: scrape_educarriere(max_jobs=50), False),
        ("Source 6: emploi.ci (Stealth)",    lambda p: scrape_emploici(max_jobs=30), False),
        ("Source 9: rmo-jobcenter.com",      lambda p: scrape_rmo(), False),
        ("Source 12: projobivoire.com",      lambda p: scrape_projobivoire(pages=[1, p]) if p > 1 else scrape_projobivoire(pages=[1]), True),
        ("Source 15: Google Web Search",     lambda p: scrape_google_search(), False),
        ("Source 16: RSS Feeds (Remote)",    lambda p: scrape_rss_feeds(), False),
        ("Source 17: Adzuna API",            lambda p: scrape_adzuna(pages=[p]), True),
    ]

    
    for idx, (name, fn, is_paginated) in enumerate(sources, 1):
        print(f"\n[{idx}] {name}", flush=True)
        
        current_page = state.get(name, 1) if is_paginated else 1
        jobs_found = scrape_source(name, fn, db, validator, totals, state_page=current_page)
        
        if is_paginated:
            # If we found 0 jobs overall this cycle, we probably hit the end of history pages.
            # We reset current_page back to 2. Otherwise increment it.
            if jobs_found > 0:
                state[name] = current_page + 1
            else:
                state[name] = 1
            save_state(state)
            
    print("\n" + "=" * 60, flush=True)
    print(f"DONE! Inserted: {totals[0]} | Skipped/Dupes: {totals[1]}", flush=True)
    print("=" * 60, flush=True)


if __name__ == "__main__":
    cycle = 0
    while True:
        cycle += 1
        print(f"DEBUG: Starting cycle {cycle}", flush=True)
        print(f"\n{'#' * 60}", flush=True)
        print(f"  AUTO-SCRAPE CYCLE #{cycle}", flush=True)
        print(f"{'#' * 60}", flush=True)
        
        try:
            main()
        except Exception as e:
            print(f"\n[CRITICAL] Main loop crashed: {e}", flush=True)
        
        print(f"\nSleeping {REFRESH_INTERVAL // 60} minutes before next update... (Ctrl+C to stop)", flush=True)
        time.sleep(REFRESH_INTERVAL)
