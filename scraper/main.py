import asyncio
import os
import sys
import time
import re
from datetime import datetime
import json
import httpx
from src.core.db_client import SupabaseClient
from src.core.ai_validator import AIJobValidator
from src.crawlers.educarriere import scrape_educarriere
from src.crawlers.emploici import scrape_emploici
from src.crawlers.rmo import scrape_rmo
from src.crawlers.projobivoire import scrape_projobivoire
from src.crawlers.google_jobs import scrape_google_jobs
from src.crawlers.google_search import scrape_google_search
from src.crawlers.rss_feeds import scrape_rss_feeds
from src.crawlers.adzuna import scrape_adzuna

print("\n🚀 DJOSSI-MATCH ULTRA-TURBO V2.3 ACTIVATED", flush=True)

REFRESH_INTERVAL = 900
STATE_FILE = "scraper_state.json"

def clean_text(text):
    protected_emails = re.findall(r'email-protection#([a-fA-F0-9]+)', text)
    for hex_val in protected_emails:
        try:
            k = int(hex_val[:2], 16)
            real_email = "".join([chr(int(hex_val[i:i+2], 16) ^ k) for i in range(2, len(hex_val), 2)])
            if real_email:
                text = text.replace(f"email-protection#{hex_val}", real_email)
        except: pass
    return text

async def process_and_store_single(job: dict, db: SupabaseClient, validator: AIJobValidator, totals: list, semaphore: asyncio.Semaphore):
    """Handles a single job with semaphore protection for AI."""
    url = job["source_url"]
    
    # NEW: Check if URL already in DB BEFORE AI analysis
    # This saves 10-60 seconds per known URL!
    if db.url_exists(url):
        # We don't print anything to keep logs clean for new jobs
        totals[1] += 1
        return False

    try:
        raw_text = clean_text(job["raw_text"])
        
        # Log wait time
        async with semaphore:
            ts = datetime.now().strftime("%H:%M:%S")
            print(f"  [{ts}] 🧠 AI Analysis for: {url.split('/')[-1][:40]}...")
            # AI Validation
            job_data = await validator.validate_and_clean_job(raw_text)
        
        if not job_data or not job_data.get("job_title"):
            totals[1] += 1
            return False

        title = job_data.get("job_title").strip()
        email = (job_data.get("contact_email") or "").strip()
        whatsapp = (job_data.get("whatsapp_number") or "").strip()
        
        # Don't insert if no contact info
        if not email and not whatsapp:
            totals[1] += 1
            return False

        job_data["source_url"] = url
        result = db.insert_job(job_data)
        if result:
            print(f"  [OK] ✅ {title[:40]} | Contact: {email or whatsapp}")
            totals[0] += 1
            return True
        else:
            totals[1] += 1
    except Exception as e:
        print(f"  [ERR] {repr(e)}")
        totals[1] += 1
    return False

async def handle_source(name, fn, arg, db, validator, totals, semaphore):
    """Full pipeline for a single source."""
    print(f"\n[SOURCE] Exploration de {name} lancée...")
    try:
        if asyncio.iscoroutinefunction(fn):
            jobs = await (fn(arg) if arg is not None else fn())
        else:
            jobs = fn(arg) if arg is not None else fn()
            
        if jobs:
            print(f"  [{name}] {len(jobs)} offres trouvées. Filtrage et analyse...")
            tasks = [process_and_store_single(job, db, validator, totals, semaphore) for job in jobs]
            await asyncio.gather(*tasks)
    except Exception as e:
        print(f"  [ERROR] Source {name} crashed: {repr(e)}")

async def run_cycle(semaphore):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"\n{'#'*60}")
    print(f" START ULTRA-TURBO CYCLE | {now} ")
    print(f"{'#'*60}")
    
    db = SupabaseClient()
    validator = AIJobValidator()
    totals = [0, 0]

    sources = [
        ("Educarriere", scrape_educarriere, 100),
        ("Emploi.ci", scrape_emploici, 50),
        ("Google Search (2026)", scrape_google_search, None),
        ("ProJob", scrape_projobivoire, 1),
        ("RMO", scrape_rmo, None),
        ("RSS Feeds", scrape_rss_feeds, None),
        ("Adzuna", scrape_adzuna, [1]),
    ]

    tasks = [handle_source(name, fn, arg, db, validator, totals, semaphore) for name, fn, arg in sources]
    await asyncio.gather(*tasks)

    print(f"\n{'='*60}")
    print(f"CYCLE TERMINE | Total Insérés: {totals[0]} | Sautés/Erreurs: {totals[1]}")
    print(f"{'='*60}")
    db.log("INFO", f"BILAN ULTRA-TURBO: {totals[0]} jobs ajoutés.")

async def main_loop():
    print("DJORSSI MATCH ULTRA-TURBO STARTING...", flush=True)
    semaphore = asyncio.Semaphore(1) 
    
    while True:
        try:
            await run_cycle(semaphore)
        except Exception as e:
            print(f"CRITICAL ERROR: {repr(e)}")
            await asyncio.sleep(60)
        
        print(f"\nProchain cycle dans {REFRESH_INTERVAL//60} min...")
        await asyncio.sleep(REFRESH_INTERVAL)

if __name__ == "__main__":
    try:
        asyncio.run(main_loop())
    except KeyboardInterrupt:
        print("\nStopping Ultra-Turbo Scraper...")
