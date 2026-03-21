import httpx
import asyncio
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import re

BASE_URL = "https://www.rmo-jobcenter.com"
JOBS_URL = "https://www.rmo-jobcenter.com/fr/cote-d-ivoire/offres-emploi.html"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Accept-Language": "fr-FR,fr;q=0.9",
}

async def fetch_rmo_detail(client: httpx.AsyncClient, link: str) -> dict:
    """Fetches RMO job details asynchronously."""
    try:
        resp = await client.get(link, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        soup = BeautifulSoup(resp.text, "html.parser")
        
        detail_content = soup.find("div", class_="offer-details") or \
                         soup.find("div", class_="content") or \
                         soup.find("div", id="job-details") or \
                         soup.find("main")
        
        if detail_content:
            raw_text = detail_content.get_text("\n", strip=True)
            if len(raw_text) > 200:
                return {
                    "raw_text": raw_text[:5000],
                    "source_url": link
                }
    except Exception:
        pass
    return None

async def scrape_rmo() -> list[dict]:
    """Scrapes job listings from RMO for Cote d'Ivoire asynchronously."""
    all_jobs = []
    print(f"  Scraping RMO: {JOBS_URL}")
    
    async with httpx.AsyncClient(follow_redirects=True) as client:
        try:
            response = await client.get(JOBS_URL, headers=HEADERS, timeout=15)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, "html.parser")
            job_links = []
            for l in soup.select("a.more, a.bleu"):
                href = l.get('href')
                if href and "/offre-emploi/" in href:
                    job_links.append(urljoin(BASE_URL, href))
                    
            job_links = list(set(job_links))
            if job_links:
                print(f"    - Found {len(job_links)} links. Fetching in parallel...")
                tasks = [fetch_rmo_detail(client, link) for link in job_links]
                results = await asyncio.gather(*tasks)
                all_jobs.extend([res for res in results if res])
        except Exception as e:
            print(f"  [ERROR] RMO failed: {repr(e)}")
    
    # Remove duplicates
    all_jobs = list({v['source_url']: v for v in all_jobs}.values())
    print(f"  [OK] RMO found {len(all_jobs)} jobs.")
    return all_jobs
