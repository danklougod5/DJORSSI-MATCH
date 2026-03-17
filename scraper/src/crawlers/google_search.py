"""
Crawler using SerpApi (Google Search) to find niche job offers across the web.
"""

import os
import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import re

load_dotenv()

SERPAPI_KEY = os.environ.get("SERPAPI_KEY")
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
}

def scrape_google_search(pages: int = 1) -> list[dict]:
    """
    Uses SerpApi to find job postings by searching Google.
    Targets unusual sites, PDFs, and landing pages.
    """
    if not SERPAPI_KEY:
        print("[WARN] SERPAPI_KEY not found in .env. Skipping web search.")
        return []

    # Search queries to find fresh recruitment pages in CIV
    queries = [
        'site:*.ci "recrutement" "offre d\'emploi" -inurl:login',
        'intitle:"recrutement" "Abidjan" "email"',
        'site:linkedin.com/posts "recrutement" "Côte d\'Ivoire" "contact@"',
        'site:*.ci "recrutement" "2025" filetype:pdf',
        'intitle:"offre d\'emploi" "Abidjan" "urgent"',
        'site:facebook.com "recrutement" "Abidjan" "email"',
        'site:novojob.com/cote-d-ivoire "offre"',
        'site:social-me.ci "recrutement"'
    ]
    
    all_jobs = []
    
    for query in queries:
        print(f"  Searching Google for: {query}")
        params = {
            "engine": "google",
            "q": query,
            "api_key": SERPAPI_KEY,
            "num": 10,
            "gl": "ci", # Côte d'Ivoire
            "hl": "fr"  # French
        }
        
        try:
            response = requests.get("https://serpapi.com/search.json", params=params, timeout=20)
            data = response.json()
            
            results = data.get("organic_results", [])
            for res in results:
                link = res.get("link")
                title = res.get("title")
                
                if not link:
                    continue
                
                # Check if it's a PDF (SerpApi usually marks these or we check extension)
                if link.lower().endswith('.pdf'):
                    print(f"    [SKIP] Found PDF: {link} (Parsing not implemented yet)")
                    continue

                print(f"    - Visiting result: {link}")
                try:
                    # Visit the page to get the full raw text
                    resp = requests.get(link, headers=HEADERS, timeout=10)
                    resp.raise_for_status()
                    
                    # Basic cleaning
                    soup = BeautifulSoup(resp.text, "html.parser")
                    
                    # Remove script and style elements
                    for script in soup(["script", "style"]):
                        script.decompose()

                    raw_text = soup.get_text("\n", strip=True)
                    
                    # Only add if it looks like a job page (simplified check)
                    if len(raw_text) > 300:
                        all_jobs.append({
                            "raw_text": raw_text[:5000],
                            "source_url": link
                        })
                except Exception as e:
                    print(f"      [WARN] Could not scrape {link}: {e}")
                    
        except Exception as e:
            print(f"  [ERROR] SerpApi search failed for '{query}': {e}")

    # Remove duplicates
    all_jobs = list({v['source_url']: v for v in all_jobs}.values())
    return all_jobs
