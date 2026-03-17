"""
Crawler for Google Jobs via SerpApi for Côte d'Ivoire.
"""

import os
import requests
from dotenv import load_dotenv

load_dotenv()

def scrape_google_jobs(page: int = 1) -> list[dict]:
    """Scrapes job listings from Google Jobs via SerpApi for Cote d'Ivoire."""
    api_key = os.getenv("SERPAPI_KEY")
    if not api_key:
        print("  [ERROR] SERPAPI_KEY mission in .env")
        return []

    # Calculate offset (first result to return)
    # Each page returns 10 results by default
    start = (page - 1) * 10

    params = {
        "engine": "google_jobs",
        "q": "offres d'emploi Côte d'Ivoire",
        "hl": "fr",
        "gl": "ci",
        "api_key": api_key,
        "start": start
    }

    print(f"  Scraping Google Jobs via SerpApi (page {page})...")
    
    try:
        response = requests.get("https://serpapi.com/search", params=params, timeout=20)
        
        # If we get a 400, it might mean no more results are available for this pagination
        if response.status_code == 400:
            print(f"  [INFO] SerpApi returned 400 (likely no more results for page {page}).")
            return []
            
        response.raise_for_status()
        results = response.json()
        
        if "error" in results:
            print(f"  [ERROR] SerpApi Error: {results['error']}")
            return []
            
    except requests.RequestException as e:
        print(f"  [ERROR] SerpApi request failed: {e}")
        return []

    jobs = []
    
    if "jobs_results" not in results:
        print(f"  [INFO] No job results found on page {page}.")
        return []

    for job in results["jobs_results"]:
        # We need to construct a rich text for the AI validator
        # SerpApi provides job highlights, description, etc.
        title = job.get("title", "")
        company = job.get("company_name", "")
        location = job.get("location", "")
        description = job.get("description", "")
        
        # Combine everything into raw_text for the AI Validator
        raw_text = f"Titre: {title}\nEntreprise: {company}\nLieu: {location}\n\nDescription:\n{description}"
        
        # Source URL: Prefer direct link if available, otherwise use SerpApi's share_link
        source_url = job.get("share_link") or f"https://www.google.com/search?q={title}+{company}&ibp=htl;jobs"

        jobs.append({
            "raw_text": raw_text[:5000],
            "source_url": source_url
        })

    print(f"  [OK] Found {len(jobs)} jobs on Google Jobs page {page}.")
    return jobs
