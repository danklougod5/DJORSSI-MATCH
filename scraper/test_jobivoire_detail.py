from src.crawlers.jobivoire import scrape_jobivoire
import re

print("=== TEST REEL JOBIVOIRE (DETAIL + EMAIL) ===")

# On récupère juste la première page pour le test
jobs = scrape_jobivoire(pages=[1])

if not jobs:
    print("Aucun job trouvé.")
else:
    print(f"\n[OK] {len(jobs)} jobs récupérés sur la page 1.")
    
    # On teste le premier job
    test_job = jobs[0]
    url = test_job['source_url']
    text = test_job['raw_text']
    
    print(f"\n--- ANALYSE DU PREMIER JOB ---")
    print(f"URL: {url}")
    print(f"Taille du texte récupéré: {len(text)} caractères")
    
    # Recherche d'emails dans le texte récupéré par le script
    emails = re.findall(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', text)
    
    print("\n--- EXTRAIT DU TEXTE (Détails) ---")
    print(text[:1000] + "...") # Affiche les 1000 premiers caractères
    
    print("\n--- CONTACTS TROUVÉS DANS LE TEXTE ---")
    if emails:
        print(f"Emails détectés : {emails}")
    else:
        print("Aucun email détecté par regex dans le texte brut.")
        
    if "Email de contact direct:" in text:
        print("Succès: Le tag 'Email de contact direct' (mailto) a été ajouté par le script !")
