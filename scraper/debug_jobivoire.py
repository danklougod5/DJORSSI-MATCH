import requests
from bs4 import BeautifulSoup
import re
from urllib.parse import urljoin

BASE_URL = "https://www.jobivoire.ci"
url = "https://www.jobivoire.ci/emploi/un-01-responsable-developpement-durable-et-rse-4667560.htm"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

import ipaddress
from urllib.parse import urlparse

def validate_url(url_str):
    parsed = urlparse(url_str)
    if parsed.scheme not in ['http', 'https']:
        raise ValueError(f"Invalid scheme: {parsed.scheme}")
    
    hostname = parsed.hostname
    if not hostname:
        raise ValueError("Invalid hostname")

    # Block localhost and private IP ranges
    try:
        ip = ipaddress.ip_address(hostname)
        if ip.is_loopback or ip.is_private or ip.is_link_local or ip.is_multicast:
            raise ValueError(f"URL not allowed: private address ({hostname})")
    except ValueError:
        # Not an IP address, check for localhost common names
        if hostname.lower() in ['localhost', '127.0.0.1', '[::1]']:
            raise ValueError(f"URL not allowed: {hostname}")

    # For this specific debug script, we only want jobivoire.ci
    if "jobivoire.ci" not in hostname:
        raise ValueError(f"URL not allowed: domain not in whitelist ({hostname})")
    
    return url_str

# Validate before use
safe_url = validate_url(url)
print(f"Testing direct visit to: {safe_url}")
detail_resp = requests.get(safe_url, headers=HEADERS, timeout=10)
detail_soup = BeautifulSoup(detail_resp.text, "html.parser")

detail_content = detail_soup.find("main") or detail_soup.find("div", class_="container") or detail_soup.find("article")

if detail_content:
    raw_text = detail_content.get_text("\n", strip=True)
    mail_tos = detail_content.find_all("a", href=re.compile(r"mailto:"))
    for m in mail_tos:
        raw_text += f"\nEmail de contact direct: {m.get('href').replace('mailto:', '')}"
else:
    raw_text = detail_soup.get_text("\n", strip=True)

with open("debug_output.txt", "w", encoding="utf-8") as f:
    f.write(raw_text)

emails = re.findall(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', raw_text)
print(f"Regex Emails: {emails}")
if "Email de contact direct:" in raw_text:
    print("MAILTO found in raw_text")
print("Done. Check debug_output.txt")
