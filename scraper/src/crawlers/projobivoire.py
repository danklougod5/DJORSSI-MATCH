import httpx
import asyncio
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import re

BASE_URL = "https://projobivoire.com"
JOBS_URL = f"{BASE_URL}/jobs/"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept-Language": "fr-FR,fr;q=0.9",
}

from scraper.src.utils.security import is_safe_url

async def fetch_projob_detail(client: httpx.AsyncClient, link: str) -> dict:
    """Fetches job details asynchronously."""
    try:
        if not is_safe_url(link):
            return None
        resp = await client.get(link, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        soup = BeautifulSoup(resp.text, "html.parser")
        
        detail_content = soup.find("div", class_="job-desc") or \
                         soup.find("div", class_="job_description") or \
                         soup.find("div", class_="entry-content") or \
                         soup.find("main")
        
        if detail_content:
            raw_text = detail_content.get_text("\n", strip=True)
            mail_tos = detail_content.find_all("a", href=re.compile(r"mailto:"))
            for m in mail_tos:
                href = m.get('href')
                if href:
                    raw_text += f"\nEmail de contact direct: {href.replace('mailto:', '')}"
        else:
            raw_text = soup.get_text("\n", strip=True)

        if len(raw_text) > 200:
            return {
                "raw_text": raw_text[:6000],
                "source_url": link
            }
    except Exception:
        pass
    return None

async def scrape_projobivoire(pages: int = 1) -> list[dict]:
    """Scrapes job listings from projobivoire.com asynchronously."""
    all_jobs = []
    
    async with httpx.AsyncClient(follow_redirects=True) as client:
        for page in range(1, pages + 1):
            url = JOBS_URL if page == 1 else f"{JOBS_URL}page/{page}/"
            print(f"  Scraping projobivoire.com page {page}: {url}")
            
            try:
                response = await client.get(url, headers=HEADERS, timeout=15)
                if response.status_code == 404:
                    break
                response.raise_for_status()
                
                soup = BeautifulSoup(response.text, "html.parser")
                links = soup.find_all("a", href=True)
                job_links = []
                for l in links:
                    href = l['href']
                    if "projobivoire.com/jobs/" in href and href != "https://projobivoire.com/jobs/":
                        job_links.append(href)
                        
                job_links = list(set(job_links))
                if job_links:
                    print(f"    - Found {len(job_links)} links. Fetching details in parallel...")
                    tasks = [fetch_projob_detail(client, link) for link in job_links]
                    results = await asyncio.gather(*tasks)
                    all_jobs.extend([res for res in results if res])
            except Exception as e:
                print(f"  [ERROR] ProJob failed on page {page}: {repr(e)}")
                break
                
    # Remove duplicates
    all_jobs = list({v['source_url']: v for v in all_jobs}.values())
    return all_jobs
