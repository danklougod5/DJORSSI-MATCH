from src.crawlers.jobivoire import scrape_jobivoire
import json
import sys

# Test page 1 and page 2
print("Testing Jobivoire Pagination and Content...")
jobs = scrape_jobivoire(pages=[1])
print(f"Found {len(jobs)} jobs on page 1.")
if len(jobs) > 0:
    print("Sample Job 1:")
    print(jobs[0]['source_url'])
    print(jobs[0]['raw_text'][:500])
    
print("--------------------------------------------------")
jobs_p2 = scrape_jobivoire(pages=[2])
print(f"Found {len(jobs_p2)} jobs on page 2.")
if len(jobs_p2) > 0:
    print("Sample Job from Page 2:")
    print(jobs_p2[0]['source_url'])
