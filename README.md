# Djossi Match

Application mobile de mise en relation directe entre employeurs et candidats en Côte d'Ivoire.

## Structure du Projet
- `/app` : Application mobile Flutter (Clean Architecture).
- `/scraper` : Moteur de scraping Python avec validation IA (Gemini).
- `/supabase` : Configuration du backend (SQL Migrations).

## Installation

### 1. Supabase
- Installez la CLI Supabase.
- Lancez `supabase start` ou configurez un projet distant.
- Appliquez les migrations dans `/supabase/migrations`.

### 2. Scraper (Python)
- `cd scraper`
- `python -m venv venv`
- `source venv/bin/activate` (ou `.\venv\Scripts\activate` sur Windows)
- `pip install -r requirements.txt`
- Créez un fichier `.env` basé sur `.env.example`.
- `python main.py`

### 3. Application Mobile (Flutter)
- `cd app`
- `flutter pub get`
- `flutter run`

## Design & UX
Le design est basé sur le concept **Vibrant & Trust** défini dans la spécification UX.
Police : **Outfit**
Couleurs : Deep Blue (#1E3A8A) & Vibrant Orange (#F97316).
