import asyncio
from playwright.async_api import async_playwright

async def scrape_educate():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        # Example Target: Educate.ci
        print("Scraping Educate.ci...")
        await page.goto("https://www.educate.ci/emplois", wait_until="networkidle")
        
        # Extract job titles and descriptions (placeholder logic)
        jobs = await page.query_selector_all(".job-listing")
        results = []
        for job in jobs[:5]: # Take first 5 for test
            title = await job.inner_text()
            results.append(title)
            
        await browser.close()
        return results

if __name__ == "__main__":
    asyncio.run(scrape_educate())
