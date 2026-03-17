from src.crawlers.projobivoire import scrape_projobivoire
import re

print("=== TEST REEL PROJOBIVOIRE ===")

# Test fetching page 1
jobs = scrape_projobivoire(pages=[1])

if not jobs:
    print("Aucun job trouvé.")
else:
    print(f"\n[OK] {len(jobs)} jobs récupérés sur la page 1.")
    
    # Check the first few jobs
    for i in range(min(3, len(jobs))):
        job = jobs[i]
        text = job['raw_text']
        url = job['source_url']
        
        print(f"\n--- JOB #{i+1} ---")
        print(f"URL: {url}")
        
        emails = re.findall(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', text)
        if emails:
            print(f"  -> EMAILS TROUVÉS: {list(set(emails))}")
        elif "Email de contact direct:" in text:
            print("  -> L'email a été trouvé via un lien mailto!")
        else:
            print("  -> Aucun email détecté dans le texte complet.")
            
        print(f"  Extrait du texte récupéré (150 derniers caractères):")
        print(f"  {text[-150:]}")
