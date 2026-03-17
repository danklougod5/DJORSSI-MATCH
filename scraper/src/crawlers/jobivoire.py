"""
Crawler for jobivoire.ci - Updated with Cloudflare Email Protection decoding.
"""

import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import re

BASE_URL = "https://www.jobivoire.ci"
JOBS_URL = f"{BASE_URL}/jobs"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

def decode_cloudflare_email(encoded_string):
    """
    Decodes a Cloudflare obfuscated email string.
    """
    try:
        r = int(encoded_string[:2], 16)
        email = ''.join([chr(int(encoded_string[i:i+2], 16) ^ r) for i in range(2, len(encoded_string), 2)])
        return email
    except Exception:
        return None

def scrape_jobivoire(pages: list[int] = None) -> list[dict]:
    """Scrapes job listings from jobivoire.ci."""
    if pages is None:
        pages = [1]
    
    all_jobs = []
    
    for page in pages:
        url = f"{JOBS_URL}?page={page}" if page > 1 else JOBS_URL
        print(f"  Scraping jobivoire.ci page {page}: {url}")
        
        try:
            response = requests.get(url, headers=HEADERS, timeout=15)
            response.raise_for_status()
        except requests.RequestException as e:
            print(f"  [ERROR] Failed to fetch {url}: {e}")
            break
        
        soup = BeautifulSoup(response.text, "html.parser")
        
        job_headers = soup.find_all("h4")
        if not job_headers:
            job_headers = soup.find_all("a", href=True)
            job_headers = [h for h in job_headers if "/emploi/" in h['href']]
        
        for header in job_headers:
            try:
                link_tag = None
                if header.name == 'a':
                    link_tag = header
                else:
                    link_tag = header.find("a") or header.find_next("a", string=lambda x: x and "Voir l'offre" in x)
                
                if not link_tag:
                    continue
                    
                link = urljoin(BASE_URL, link_tag["href"])
                if "/emploi/" not in link:
                    continue

                print(f"    - Visiting: {link}")
                detail_resp = requests.get(link, headers=HEADERS, timeout=10)
                detail_soup = BeautifulSoup(detail_resp.text, "html.parser")
                
                detail_content = detail_soup.find("main") or detail_soup.find("div", class_="container") or detail_soup.find("article")
                
                if detail_content:
                    # Capture hidden Cloudflare emails
                    cf_emails = detail_content.find_all("span", class_="__cf_email__")
                    decoded_list = []
                    for cf in cf_emails:
                        enc = cf.get("data-cfemail")
                        if enc:
                            decoded = decode_cloudflare_email(enc)
                            if decoded:
                                decoded_list.append(decoded)
                                # Replace the [email protected] text or just add it to raw_text
                    
                    raw_text = detail_content.get_text("\n", strip=True)
                    
                    if decoded_list:
                        raw_text += "\nEmails de contact décodés: " + ", ".join(list(set(decoded_list)))

                    # Also explicitly look for mailto links (sometimes they have the encoded string too)
                    mail_tos = detail_content.find_all("a", href=re.compile(r"mailto:"))
                    for m in mail_tos:
                        href = m.get('href')
                        if "email-protection" in href:
                            # Extract encoded part from mailto:#...
                            m_match = re.search(r'email-protection#([a-fA-F0-9]+)', href)
                            if m_match:
                                decoded = decode_cloudflare_email(m_match.group(1))
                                if decoded:
                                    raw_text += f"\nEmail de contact mailto décodé: {decoded}"
                        else:
                            raw_text += f"\nEmail de contact direct: {href.replace('mailto:', '')}"
                else:
                    raw_text = detail_soup.get_text("\n", strip=True)

                raw_text = re.sub(r'info@jobivoire\.ci', '', raw_text, flags=re.IGNORECASE)
                raw_text = re.sub(r'contact@jobivoire\.ci', '', raw_text, flags=re.IGNORECASE)

                if len(raw_text) > 150:
                    all_jobs.append({
                        "raw_text": raw_text[:5000],
                        "source_url": link
                    })
                
            except Exception as e:
                print(f"      [WARN] Detail visit failed: {e}")
                continue
        
        all_jobs = list({v['source_url']: v for v in all_jobs}.values())
        print(f"  [OK] Found {len(all_jobs)} jobs so far.")
    
    return all_jobs
