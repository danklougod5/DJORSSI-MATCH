import requests
from bs4 import BeautifulSoup
import re
from urllib.parse import urljoin

BASE_URL = "https://www.jobivoire.ci"
url = "https://www.jobivoire.ci/emploi/un-01-responsable-developpement-durable-et-rse-4667560.htm"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

print(f"Testing direct visit to: {url}")
detail_resp = requests.get(url, headers=HEADERS, timeout=10)
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
