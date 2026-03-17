"""
Crawler for projobivoire.com
"""

import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import re

BASE_URL = "https://projobivoire.com"
JOBS_URL = f"{BASE_URL}/jobs/"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept-Language": "fr-FR,fr;q=0.9",
}

def scrape_projobivoire(pages: list[int] = None) -> list[dict]:
    """Scrapes job listings from projobivoire.com"""
    if pages is None:
        pages = [1]
        
    all_jobs = []
    
    for page in pages:
        # Assuming pagination is /jobs/page/2/ or something similar if applicable
        # Projobivoire uses /page/2/ or ?paged=2
        url = JOBS_URL if page == 1 else f"{JOBS_URL}page/{page}/"
        print(f"  Scraping projobivoire.com page {page}: {url}")
        
        try:
            response = requests.get(url, headers=HEADERS, timeout=15)
            if response.status_code == 404:
                # End of pagination reached
                break
            response.raise_for_status()
        except requests.RequestException as e:
            print(f"  [ERROR] Failed to fetch {url}: {e}")
            break
        
        soup = BeautifulSoup(response.text, "html.parser")
        
        # Look for links that represent job posts
        links = soup.find_all("a", href=True)
        job_links = []
        for l in links:
            href = l['href']
            # job URLs on projobivoire are usually like /jobs/titre-du-poste/
            if "projobivoire.com/jobs/" in href and href != "https://projobivoire.com/jobs/":
                job_links.append(href)
                
        job_links = list(set(job_links))
        
        for link in job_links:
            try:
                print(f"    - Visiting: {link}")
                detail_resp = requests.get(link, headers=HEADERS, timeout=10)
                detail_soup = BeautifulSoup(detail_resp.text, "html.parser")
                
                # Projobivoire usually has content in job-desc
                detail_content = detail_soup.find("div", class_="job-desc") or \
                                 detail_soup.find("div", class_="job_description") or \
                                 detail_soup.find("div", class_="entry-content") or \
                                 detail_soup.find("main")
                
                if detail_content:
                    raw_text = detail_content.get_text("\n", strip=True)
                    # Also explicitly look for mailto links just in case
                    mail_tos = detail_content.find_all("a", href=re.compile(r"mailto:"))
                    for m in mail_tos:
                        href = m.get('href')
                        if href:
                            raw_text += f"\nEmail de contact direct: {href.replace('mailto:', '')}"
                else:
                    raw_text = detail_soup.get_text("\n", strip=True)

                if len(raw_text) > 150:
                    all_jobs.append({
                        "raw_text": raw_text[:5000],
                        "source_url": link
                    })
            except Exception as e:
                print(f"      [WARN] Detail visit failed: {e}")
                continue
                
        print(f"  [OK] Page {page}: {len(all_jobs)} jobs so far.")
    
    # Remove duplicates
    all_jobs = list({v['source_url']: v for v in all_jobs}.values())
    return all_jobs
