"""
Improved Crawler for emploi.ci - Uses Playwright with Stealth to bypass Cloudflare.
"""

import asyncio
from playwright.async_api import async_playwright
from playwright_stealth import Stealth
import random

BASE_URL = "https://www.emploi.ci"
SEARCH_URL = BASE_URL  # Start with home page, it usually has the latest jobs

async def scrape_emploici_async(max_jobs: int = 10) -> list[dict]:
    """Scrapes job listings from emploi.ci using stealth mode."""
    all_jobs = []
    
    async with async_playwright() as p:
        # Launch browser with a specific user agent
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            viewport={"width": 1920, "height": 1080}
        )
        
        page = await context.new_page()
        # Apply stealth to the page
        await Stealth().apply_stealth_async(page)
        
        print(f"  Scraping emploi.ci (Stealth): {SEARCH_URL}")
        
        try:
            # Go to the search/listing page instead of home
            await page.goto(SEARCH_URL, wait_until="domcontentloaded", timeout=60000)
            
            # Additional wait to simulate human behavior
            await asyncio.sleep(random.uniform(5, 10))
            
            # Take a generic approach: look for ANY link that looks like a job offer
            all_links = await page.eval_on_selector_all("a[href]", "els => els.map(el => el.href)")
            print(f"    [DEBUG] Found {len(all_links)} links total.")
            
            # Find job links
            # emploi.ci cards often have links like /offre-emploi-cote-ivoire/...
            # Find job links
            all_links = await page.eval_on_selector_all("a[href]", "els => els.map(el => el.href)")
            print(f"    [DEBUG] Total links found: {len(all_links)}")
            if all_links:
                print(f"    [DEBUG] Sample links: {all_links[:5]}")

            job_links = [l for l in all_links if "/offre-emploi-cote-ivoire/" in l]

            # Remove duplicates and filter out non-job links
            job_links = list(dict.fromkeys(job_links))
            job_links = [l for l in job_links if "/offre-emploi-cote-ivoire/" in l]
            
            print(f"  [OK] Found {len(job_links)} potential job links.")
            
            for i, job_url in enumerate(job_links[:max_jobs]):
                try:
                    print(f"    - Visiting Detail {i+1}: {job_url.split('/')[-1][:30]}...")
                    await page.goto(job_url, wait_until="domcontentloaded", timeout=30000)
                    await asyncio.sleep(random.uniform(1, 3)) # Human delay
                    
                    # Target the main job content
                    # Emploi.ci usually has the content in a container with a specific class or ID
                    content = await page.inner_text("div.job-ad-details, div.block-job-ad, article, main")
                    
                    if len(content) > 200:
                        all_jobs.append({
                            "raw_text": content[:4000],
                            "source_url": job_url
                        })
                    else:
                        print(f"    [WARN] Content too short for {job_url}")
                        
                except Exception as e:
                    print(f"    [ERROR] Failed to visit {job_url}: {e}")
                    continue
        
        except Exception as e:
            print(f"  [ERROR] Failed during emploi.ci scrape: {e}")
        
        await browser.close()
    
    return all_jobs

def scrape_emploici(max_jobs: int = 10) -> list[dict]:
    """Synchronous wrapper."""
    return asyncio.run(scrape_emploici_async(max_jobs))
