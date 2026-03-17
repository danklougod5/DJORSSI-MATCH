"""
Scrapes job listings from various RSS feeds.
"""
import feedparser
from bs4 import BeautifulSoup
import time

def clean_html(html_content):
    if not html_content:
        return ""
    soup = BeautifulSoup(html_content, 'html.parser')
    return soup.get_text(separator='\n', strip=True)

def scrape_rss_feeds():
    """Scrapes multiple RSS feeds and returns common format jobs."""
    print("  [RSS] Starting RSS feed scraping...")
    
    feeds = [
        # Remote & Tech (Global)
        "https://weworkremotely.com/categories/remote-front-end-programming-jobs.rss",
        "https://weworkremotely.com/categories/remote-back-end-programming-jobs.rss",
        "https://weworkremotely.com/categories/remote-full-stack-programming-jobs.rss",
        "https://weworkremotely.com/categories/remote-design-jobs.rss",
        "https://weworkremotely.com/categories/remote-customer-support-jobs.rss",
        "https://weworkremotely.com/categories/remote-marketing-jobs.rss",
        "https://remoteok.com/remote-jobs.rss",
        
        # Ivory Coast & Africa Specific (NGOs, Development, Public)
        "https://reliefweb.int/country/civ/jobs/rss.xml", # Côte d'Ivoire Humanitarian/NGO jobs
        "https://ngojobsinafrica.com/country/ivory-coast/feed/", # NGOs in Ivory Coast
        "https://www.afdb.org/en/about/corporate-information/employment-opportunities/vacancies/feed", # African Development Bank (based in Abidjan)
        
        # International Development (Africa focus)
        "https://unjobs.org/countries/cote-d-ivoire/rss", # UN Jobs Ivory Coast
    ]
    
    jobs = []
    
    for feed_url in feeds:
        print(f"  [RSS] Parsing {feed_url}")
        try:
            feed = feedparser.parse(feed_url)
            
            # Limit to top 15 entries per feed to prevent taking too long
            for entry in feed.entries[:15]:
                link = entry.get('link', '')
                title = entry.get('title', '')
                
                # We need a valid link
                if not link:
                    continue
                    
                # Combine fields for AI
                desc = entry.get('description', '')
                summary = entry.get('summary', '')
                
                company = entry.get('author', '')
                
                tags_str = ""
                if 'tags' in entry:
                    tags_str = ", ".join([tag.get('term', '') for tag in entry.tags])
                    
                full_text = f"Title: {title}\nCompany: {company}\nCategories/Tags: {tags_str}\n\nDescription:\n{clean_html(desc)}\n{clean_html(summary)}"
                
                jobs.append({
                    "source_url": link,
                    "raw_text": full_text
                })
        except Exception as e:
            print(f"  [RSS] Error parsing {feed_url}: {e}")
            
    print(f"  [RSS] Found {len(jobs)} total jobs across all feeds.")
    return jobs
