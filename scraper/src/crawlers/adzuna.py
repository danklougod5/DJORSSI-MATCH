"""
Crawler for Adzuna API - Integrating structured job data.
"""

import os
import requests
from dotenv import load_dotenv

load_dotenv()

ADZUNA_APP_ID = os.getenv("ADZUNA_APP_ID")
ADZUNA_APP_KEY = os.getenv("ADZUNA_APP_KEY")
# Country 'fr' is a good baseline for French speaking jobs, 
# 'at', 'au', 'be', 'br', 'ca', 'ch', 'de', 'es', 'fr', 'gb', 'in', 'it', 'mx', 'nl', 'nz', 'pl', 'ru', 'us', 'za'
COUNTRY = "fr" 

def scrape_adzuna(pages: list[int] = None) -> list[dict]:
    """Retrieves job listings from Adzuna API."""
    if not ADZUNA_APP_ID or not ADZUNA_APP_KEY:
        print("  [ERROR] Adzuna credentials missing in .env")
        return []
        
    if pages is None:
        pages = [1]
    
    all_jobs = []
    
    # We broaden search to find French speaking jobs, or specifically Cote d'Ivoire if supported
    # Note: Adzuna doesn't explicitly support 'ci' in its public country list, 
    # so we search in 'fr' with query keywords or use global if available.
    
    for page in pages:
        print(f"  Fetching Adzuna page {page}...")
        url = f"https://api.adzuna.com/v1/api/jobs/{COUNTRY}/search/{page}"
        params = {
            "app_id": ADZUNA_APP_ID,
            "app_key": ADZUNA_APP_KEY,
            "results_per_page": 20,
            "what": "Côte d'Ivoire", # Focused on the country
            "content-type": "application/json"
        }
        
        try:
            response = requests.get(url, params=params, timeout=15)
            response.raise_for_status()
            data = response.json()
            
            results = data.get("results", [])
            for job in results:
                title = job.get("title", "")
                description = job.get("description", "")
                company = job.get("company", {}).get("display_name", "N/A")
                location = job.get("location", {}).get("display_name", "N/A")
                salary_min = job.get("salary_min", "")
                salary_max = job.get("salary_max", "")
                redirect_url = job.get("redirect_url", "")
                
                # Format into raw_text like other scrapers
                raw_text = f"Titre: {title}\nEntreprise: {company}\nLocalisation: {location}\n"
                if salary_min or salary_max:
                    raw_text += f"Salaire: {salary_min} - {salary_max}\n"
                raw_text += f"\nDescription:\n{description}"
                
                all_jobs.append({
                    "raw_text": raw_text,
                    "source_url": redirect_url
                })
                
        except Exception as e:
            print(f"  [ERROR] Adzuna API call failed: {e}")
            break
            
    print(f"  [OK] Found {len(all_jobs)} jobs from Adzuna.")
    return all_jobs
