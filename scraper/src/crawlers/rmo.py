"""
Crawler for rmo-jobcenter.com - Cote d'Ivoire jobs.
"""

import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import re

BASE_URL = "https://www.rmo-jobcenter.com"
JOBS_URL = "https://www.rmo-jobcenter.com/fr/cote-d-ivoire/offres-emploi.html"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Accept-Language": "fr-FR,fr;q=0.9",
}

def scrape_rmo(pages: list[int] = None) -> list[dict]:
    """Scrapes job listings from RMO for Cote d'Ivoire."""
    # NOTE: RMO uses AJAX POST for pagination (ajax_navigation.php).
    # Since URL parameters like ?page= are ignored, we focus on the first page
    # which contains the 20 most recent offers.
    
    all_jobs = []
    print(f"  Scraping RMO: {JOBS_URL}")
    
    try:
        response = requests.get(JOBS_URL, headers=HEADERS, timeout=15)
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"  [ERROR] Failed to fetch {JOBS_URL}: {e}")
        return []
    
    soup = BeautifulSoup(response.text, "html.parser")
    
    # Target links with class 'more' or 'bleu' that go to job details
    job_links = []
    for l in soup.select("a.more, a.bleu"):
        href = l.get('href')
        if href and "/offre-emploi/" in href:
            job_links.append(urljoin(BASE_URL, href))
                
    job_links = list(set(job_links))
    print(f"  Found {len(job_links)} potential job links on RMO.")
    
    for link in job_links:
        try:
            print(f"    - Visiting: {link}")
            detail_resp = requests.get(link, headers=HEADERS, timeout=10)
            detail_soup = BeautifulSoup(detail_resp.text, "html.parser")
            
            # Target detail content - usually in 'offer-details' or similar
            detail_content = detail_soup.find("div", class_="offer-details") or \
                             detail_soup.find("div", class_="content") or \
                             detail_soup.find("div", id="job-details") or \
                             detail_soup.find("main")
            
            if detail_content:
                raw_text = detail_content.get_text("\n", strip=True)
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
    
    # Remove duplicates
    all_jobs = list({v['source_url']: v for v in all_jobs}.values())
    print(f"  [OK] RMO: Collected {len(all_jobs)} jobs.")
    return all_jobs
