import asyncio
import os
import sys
from playwright.async_api import async_playwright

async def generate_pdf():
    async with async_playwright() as p:
        print("Lancement du navigateur Chromium en arrière-plan...")
        try:
            browser = await p.chromium.launch(headless=True)
        except Exception as e:
            print(f"Erreur lors du lancement de Chromium: {e}")
            print("Tentative d'installation des navigateurs requis par Playwright...")
            import subprocess
            subprocess.run([sys.executable, "-m", "playwright", "install", "chromium"])
            browser = await p.chromium.launch(headless=True)
            
        page = await browser.new_page()
        
        base_dir = os.path.dirname(os.path.abspath(__file__))
        html_path = os.path.join(base_dir, "memoire_complet.html")
        file_url = f"file://{html_path}"
        
        print(f"Chargement du document : {file_url}...")
        await page.goto(file_url, wait_until="networkidle")
        
        # Laisser le temps à Mermaid.js de rendre tous les diagrammes
        print("Rendu en cours des diagrammes et des images...")
        await asyncio.sleep(3)
        
        # Activer le mode d'impression pour appliquer la feuille de style @media print (hacher les boutons)
        print("Activation du profil d'impression (masquage des boutons de téléchargement)...")
        await page.emulate_media(media="print")
        
        pdf_path = os.path.join(base_dir, "memoire_complet.pdf")
        print(f"Génération du PDF académique dans : {pdf_path}...")
        
        # Exporter au format A4 avec arrière-plans activés et marges régulières
        await page.pdf(
            path=pdf_path,
            format="A4",
            print_background=True,
            prefer_css_page_size=False,
            margin={
                "top": "20mm",
                "bottom": "20mm",
                "left": "20mm",
                "right": "20mm"
            }
        )
        print(f"Félicitations ! Le PDF a été généré avec succès dans : {pdf_path}")
        await browser.close()

if __name__ == "__main__":
    asyncio.run(generate_pdf())
