import os
import httpx
import asyncio
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import re

load_dotenv()

SERPAPI_KEY = os.environ.get("SERPAPI_KEY")
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
}

from scraper.src.utils.security import is_safe_url

async def fetch_page_content(client: httpx.AsyncClient, link: str) -> dict:
    """Visits a page to get the full raw text asynchronously."""
    try:
        if not is_safe_url(link):
            print(f"  [WARN] Skipping unsafe URL for SSRF protection: {link}")
            return None
            
        if link.lower().endswith('.pdf'):
            # Placeholder for future PDF parsing
            return None
            
        resp = await client.get(link, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        
        soup = BeautifulSoup(resp.text, "html.parser")
        
        # Remove noisy elements
        for element in soup(["script", "style", "nav", "footer", "aside"]):
            element.decompose()

        raw_text = soup.get_text("\n", strip=True)
        
        # Only add if it seems like a real page with actual text
        if len(raw_text) > 400:
            return {
                "raw_text": raw_text[:8000], # Grab more text for better context
                "source_url": link
            }
    except Exception:
        pass
    return None

async def scrape_google_search(pages: int = 1) -> list[dict]:
    """
    Uses SerpApi to find job postings by searching Google.
    Updated for 2026 - Turbo Async Edition.
    """
    if not SERPAPI_KEY:
        print("[WARN] SERPAPI_KEY missing. Skipping web search.")
        return []

    # Aggressive & Hyper-Targeted queries for 2026 (Abidjan focus)
    queries = [
        'site:*.ci "recrutement" "offre d\'emploi" "2026" -inurl:login',
        'intitle:"recrutement" "Abidjan" "email" "2026"',
        'site:linkedin.com/posts "recrutement" "Côte d\'Ivoire" "contact@"',
        'site:facebook.com "recrutement" "Abidjan" "email" "2026"',
        'site:facebook.com/groups "recrutement" "Abidjan" "2026"',
        'site:facebook.com "Abidjan" "Hiring" "Contact" "2026"',
        'site:*.ci "recrutement" "avant le" "2026" filetype:pdf',
        'site:educarriere.ci "offre" "2026"',
        'site:novojob.com/cote-d-ivoire "offre" "2026"',
        'site:social-me.ci "recrutement" "2026"',
        '"nous recrutons" abidjan CV "2026"',
        'site:linkedin.com/posts "abidjan" "hiring" "contact"',
        'site:*.ci "avis de recrutement" "2026"',
        'site:ci.indeed.com "abidjan" "2026"',
        'intitle:"poste de" abidjan "urgent"',
    ]
    
    all_jobs = []
    
    # Use httpx for parallel network calls
    async with httpx.AsyncClient(follow_redirects=True) as client:
        for idx, query in enumerate(queries):
            print(f"  [GOOGLE] {idx+1}/{len(queries)} Searching: {query}...")
            params = {
                "engine": "google",
                "q": query,
                "api_key": SERPAPI_KEY,
                "num": 30, # Maximize results per query
                "gl": "ci",
                "hl": "fr"
            }
            
            try:
                # SerpApi is fast but why not await nicely
                response = await client.get("https://serpapi.com/search.json", params=params, timeout=20)
                data = response.json()
                
                results = data.get("organic_results", [])
                links = [res.get("link") for res in results if res.get("link")]
                
                if links:
                    print(f"    - Found {len(links)} links. Crawling in parallel...")
                    # CRAWL ALL LINKS IN PARALLEL! TURBO!
                    tasks = [fetch_page_content(client, link) for link in links]
                    page_results = await asyncio.gather(*tasks)
                    
                    for res in page_results:
                        if res:
                            all_jobs.append(res)
                        
            except Exception as e:
                print(f"  [ERROR] SerpApi search failed for '{query}': {e}")
            
    # Remove duplicates by source_url
    all_jobs = list({v['source_url']: v for v in all_jobs}.values())
    print(f"  [OK] Google Turbo Search found {len(all_jobs)} total raw jobs.")
    return all_jobs
