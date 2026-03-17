from src.crawlers.jobivoire import scrape_jobivoire
import re

print("=== TEST REEL JOBIVOIRE (VERIFICATION DE CHAQUE JOB) ===")

jobs = scrape_jobivoire(pages=[1])

if not jobs:
    print("Aucun job trouvé.")
else:
    print(f"\n[OK] {len(jobs)} jobs récupérés sur la page 1.")
    
    for i, test_job in enumerate(jobs):
        url = test_job['source_url']
        text = test_job['raw_text']
        
        # Recherche d'emails dans le texte récupéré (regex large)
        emails = re.findall(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', text)
        
        print(f"\nJob #{i+1}: {url}")
        if emails:
            print(f"  -> EMAILS TROUVÉS: {emails}")
        elif "Email de contact direct:" in text:
            print(f"  -> TAG MAILTO TROUVÉ (Email extrait du lien)")
        else:
            print(f"  -> Aucun email trouvé. (Texte: {len(text)} chars)")
            # On affiche la fin du texte pour voir si l'email de contact est là
            print(f"  Extrait fin du texte:\n{text[-300:]}\n")
