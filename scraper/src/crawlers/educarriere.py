"""
Crawler for emploi.educarriere.ci - Scrapes job listings.
This site renders job listings in HTML, so we use requests + BeautifulSoup.
"""

import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import re

BASE_URL = "https://emploi.educarriere.ci"
JOBS_LIST_URL = f"{BASE_URL}/emploi/page/all"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

def scrape_job_detail(job_url: str) -> str:
    """Fetches the full detail of a job offer to get more context."""
    try:
        response = requests.get(job_url, headers=HEADERS, timeout=15)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")
        
        # Target the main content area
        content_div = soup.find("div", class_="offreemploi") or soup.find("main") or soup.find("article")
        if content_div:
            return content_div.get_text(separator=" ", strip=True)
        return soup.get_text(separator=" ", strip=True)[:2000]
    except Exception as e:
        print(f"  [WARN] Could not fetch detail for {job_url}: {e}")
        return ""


def scrape_educarriere(max_jobs: int = 20) -> list[dict]:
    """Scrapes job listings from emploi.educarriere.ci."""
    all_jobs = []
    
    print(f"  Scraping educarriere.ci: {JOBS_LIST_URL}")
    
    try:
        response = requests.get(JOBS_LIST_URL, headers=HEADERS, timeout=15)
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"  [ERROR] Failed to fetch {JOBS_LIST_URL}: {e}")
        return []
    
    soup = BeautifulSoup(response.text, "html.parser")
    
    # Find all job links from the listing page
    # Pattern: offre-XXXXXX-job-slug.html
    job_links = []
    for a_tag in soup.find_all("a", href=True):
        href = a_tag["href"]
        if "/offre-" in href:
            full_url = urljoin(BASE_URL, href)
            if full_url not in job_links:
                job_links.append(full_url)
    
    print(f"  [OK] Found {len(job_links)} unique job links. Fetching details for up to {max_jobs}...")
    
    for job_url in job_links[:max_jobs]:
        detail_text = scrape_job_detail(job_url)
        if detail_text:
            # Strip generic educarriere emails
            detail_text = re.sub(r'[\w\.-]+@educarriere\.(ci|com|net)', '', detail_text, flags=re.IGNORECASE)
            
            all_jobs.append({
                "raw_text": detail_text[:3000],  # Limit to avoid token overflow
                "source_url": job_url
            })
    
    return all_jobs
