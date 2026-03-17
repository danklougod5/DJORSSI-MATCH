from src.crawlers.google_search import scrape_google_search
import json

print("Testing Google Search Crawler...")
jobs = scrape_google_search()
print(f"Found {len(jobs)} jobs.")
for i, job in enumerate(jobs[:2]):
    print(f"\nJob {i+1}:")
    print(f"Source: {job['source_url']}")
    print(f"Text snippet: {job['raw_text'][:200]}...")
