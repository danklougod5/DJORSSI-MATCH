"""
Improved Async Crawler for emploi.ci - Uses Playwright with Stealth.
Updated for Turbo Architecture.
"""

import asyncio
from playwright.async_api import async_playwright
from playwright_stealth import Stealth
import random

BASE_URL = "https://www.emploi.ci"
# The search results page often gives better structured data quickly
SEARCH_URL = f"{BASE_URL}/recherche-jobs-cote-ivoire"

async def scrape_emploici(max_jobs: int = 50) -> list[dict]:
    """Scrapes job listings from emploi.ci using stealth mode (Async)."""
    all_jobs = []
    
    async with async_playwright() as p:
        # Launch browser with human-like configurations
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            viewport={"width": 1920, "height": 1080}
        )
        
        page = await context.new_page()
        # Apply stealth to avoid Cloudflare challenges
        await Stealth().apply_stealth_async(page)
        
        print(f"  [PLAYWRIGHT] Scraping emploi.ci: {SEARCH_URL}")
        
        try:
            # Go to the search page
            await page.goto(SEARCH_URL, wait_until="domcontentloaded", timeout=60000)
            
            # Additional wait to load content fully
            await asyncio.sleep(random.uniform(3, 6))
            
            # Extract links with a specific pattern
            all_links = await page.eval_on_selector_all("a[href]", "els => els.map(el => el.href)")
            job_links = list(dict.fromkeys([l for l in all_links if "/offre-emploi-cote-ivoire/" in l]))
            
            print(f"    - Found {len(job_links)} potential job links on Emploi.ci.")
            
            # Visit details sequentially (due to browser instance context, 
            # though we could open more tabs if needed)
            for i, job_url in enumerate(job_links[:max_jobs]):
                try:
                    print(f"    - Visiting {i+1}: {job_url.split('/')[-1][:25]}...")
                    # Fast visit
                    await page.goto(job_url, wait_until="domcontentloaded", timeout=30000)
                    
                    # Target the main body of the job offer
                    content = await page.inner_text("div.block-job-ad, article, main")
                    
                    if len(content) > 300:
                        all_jobs.append({
                            "raw_text": content[:5000],
                            "source_url": job_url
                        })
                except Exception:
                    continue
        
        except Exception as e:
            print(f"  [ERROR] emploi.ci scrape failed: {e}")
        
        await browser.close()
    
    return all_jobs
