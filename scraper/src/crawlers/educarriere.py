import httpx
import asyncio
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import re

BASE_URL = "https://emploi.educarriere.ci"
JOBS_LIST_URL = f"{BASE_URL}/emploi/page/all"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

from scraper.src.utils.security import is_safe_url

async def scrape_job_detail(client: httpx.AsyncClient, job_url: str) -> str:
    """Fetches the full detail of a job offer to get more context asynchronously."""
    try:
        if not is_safe_url(job_url):
            return ""
        response = await client.get(job_url, headers=HEADERS, timeout=15)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")
        
        # Target the main content area
        content_div = soup.find("div", class_="offreemploi") or soup.find("main") or soup.find("article")
        
        if content_div:
            # REMOVE suggested jobs ("VOIR AUSSI") and sidebars
            for noisy in content_div.find_all(string=re.compile(r'VOIR AUSSI', re.I)):
                parent = noisy.find_parent()
                if parent:
                    # Remove everything after "VOIR AUSSI"
                    for sibling in list(parent.find_next_siblings()):
                        sibling.decompose()
                    parent.decompose()
            
            # Also remove footers, navs, asides
            for tag in content_div.find_all(['aside', 'nav', 'footer']):
                tag.decompose()
            
            raw_text = content_div.get_text(separator="\n", strip=True)
        else:
            raw_text = soup.get_text(separator="\n", strip=True)
        
        # Clean out Educarriere's own generic emails (not job emails)
        raw_text = re.sub(r'ci@educarriere\.net', '', raw_text, flags=re.IGNORECASE)
        raw_text = re.sub(r'info@educarriere\.ci', '', raw_text, flags=re.IGNORECASE)
        raw_text = re.sub(r'contact@educarriere\.ci', '', raw_text, flags=re.IGNORECASE)
        
        return raw_text
        
    except Exception as e:
        print(f"  [WARN] Could not fetch detail for {job_url}: {repr(e)}")
        return ""


async def scrape_educarriere(max_jobs: int = 50) -> list[dict]:
    """Scrapes job listings from emploi.educarriere.ci asynchronously."""
    all_jobs = []
    
    print(f"  Scraping educarriere.ci: {JOBS_LIST_URL}")
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(JOBS_LIST_URL, headers=HEADERS, timeout=15)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, "html.parser")
            
            # Find all job links from the listing page
            job_links = []
            for a_tag in soup.find_all("a", href=True):
                href = a_tag["href"]
                if "/offre-" in href:
                    full_url = urljoin(BASE_URL, href)
                    if full_url not in job_links:
                        job_links.append(full_url)
            
            print(f"  [OK] Found {len(job_links)} unique job links. Fetching details in parallel (max {max_jobs})...")
            
            # Process in parallel with a limited set of concurrent tasks
            tasks = [scrape_job_detail(client, url) for url in job_links[:max_jobs]]
            results = await asyncio.gather(*tasks)
            
            for i, detail_text in enumerate(results):
                if detail_text and len(detail_text) > 150:
                    all_jobs.append({
                        "raw_text": detail_text[:10000],
                        "source_url": job_links[i]
                    })
    
    except Exception as e:
        print(f"  [ERROR] Failed to fetch or process {JOBS_LIST_URL}: {repr(e)}")
        return []
    
    return all_jobs
