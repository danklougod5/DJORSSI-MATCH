import os
import sys
import subprocess

def install_and_import(package):
    try:
        import markdown
    except ImportError:
        print(f"Installation de la bibliothèque '{package}' pour la conversion Markdown...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        import markdown
    return markdown

def compile_markdown_to_html(md_path, html_path):
    markdown = install_and_import('markdown')
    
    if not os.path.exists(md_path):
        print(f"Erreur : Le fichier {md_path} n'existe pas.")
        return False
        
    print(f"Lecture du mémoire depuis : {md_path}")
    with open(md_path, 'r', encoding='utf-8') as f:
        md_content = f.read()

    # Configuration des extensions Markdown pour avoir des tables et des TOC
    # markdown.extensions.extra inclut les tables, les blocs de code, etc.
    html_body = markdown.markdown(md_content, extensions=['extra', 'codehilite', 'toc'])

    # Style académique de niveau supérieur pour le mémoire
    css_styles = """
    @import url('https://fonts.googleapis.com/css2?family=Crimson+Pro:ital,wght@0,300;0,400;0,600;0,700;1,400&family=Inter:wght@400;500;600;700&display=swap');

    :root {
        --font-serif: 'Crimson Pro', 'Georgia', 'Times New Roman', serif;
        --font-sans: 'Inter', system-ui, -apple-system, sans-serif;
        --color-text: #1a1a1a;
        --color-muted: #555555;
        --color-primary: #1e3a8a; /* Deep Academic Blue */
        --color-border: #e2e8f0;
    }

    * {
        box-sizing: border-box;
    }

    body {
        font-family: var(--font-serif);
        font-size: 12pt;
        line-height: 1.6;
        color: var(--color-text);
        background-color: #ffffff;
        margin: 0;
        padding: 0;
    }

    /* Conteneur principal simulant une page de mémoire */
    .memoire-container {
        max-width: 800px;
        margin: 40px auto;
        padding: 50px 70px;
        background: #ffffff;
        box-shadow: 0 4px 12px rgba(0,0,0,0.05);
        border-radius: 8px;
    }

    /* Règle spécifique pour l'impression physique et PDF */
    @media print {
        body {
            font-size: 12pt;
            background-color: #ffffff;
        }
        .memoire-container {
            max-width: 100%;
            margin: 0;
            padding: 0;
            box-shadow: none;
            border-radius: 0;
        }
        .page-break {
            page-break-before: always;
            break-before: page;
        }
        a {
            text-decoration: none;
            color: var(--color-text);
        }
        .no-print {
            display: none;
        }
    }

    /* Typographie */
    h1, h2, h3, h4, h5, h6 {
        font-family: var(--font-sans);
        color: var(--color-primary);
        font-weight: 700;
        line-height: 1.3;
        margin-top: 1.5em;
        margin-bottom: 0.5em;
        page-break-after: avoid;
    }

    h1 {
        font-size: 24pt;
        text-align: center;
        margin-top: 2em;
        margin-bottom: 1.5em;
        text-transform: uppercase;
        border-bottom: 2px solid var(--color-primary);
        padding-bottom: 15px;
    }

    h2 {
        font-size: 18pt;
        border-bottom: 1px solid var(--color-border);
        padding-bottom: 8px;
        margin-top: 2.2em;
    }

    h3 {
        font-size: 14pt;
        margin-top: 1.8em;
    }

    h4 {
        font-size: 12pt;
        color: var(--color-muted);
        font-weight: 600;
    }

    p {
        margin-top: 0;
        margin-bottom: 1.2em;
        text-align: justify;
        text-indent: 1.5em; /* Retrait de première ligne typiquement académique */
    }

    p.no-indent {
        text-indent: 0;
    }

    /* Listes */
    ul, ol {
        margin-top: 0;
        margin-bottom: 1.2em;
        padding-left: 2em;
    }

    li {
        margin-bottom: 0.5em;
        text-align: justify;
    }

    /* Citations / Extraits */
    blockquote {
        font-style: italic;
        border-left: 4px solid var(--color-primary);
        margin: 1.5em 0;
        padding: 0.5em 1.5em;
        color: var(--color-muted);
        background-color: #f8fafc;
        text-indent: 0;
    }
    
    blockquote p {
        text-indent: 0;
        margin-bottom: 0;
    }

    /* Tableaux */
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 2em 0;
        font-size: 11pt;
        font-family: var(--font-sans);
        page-break-inside: avoid;
    }

    th, td {
        border: 1px solid var(--color-border);
        padding: 10px 12px;
        text-align: left;
    }

    th {
        background-color: #f1f5f9;
        font-weight: 600;
        color: var(--color-primary);
    }

    tr:nth-child(even) {
        background-color: #f8fafc;
    }

    /* Blocs de code (Mermaid et placeholders de captures) */
    pre {
        background-color: #f8fafc;
        border: 1px solid var(--color-border);
        border-radius: 6px;
        padding: 15px;
        overflow-x: auto;
        font-family: Consolas, Monaco, 'Courier New', monospace;
        font-size: 10pt;
        margin: 1.5em 0;
        page-break-inside: avoid;
    }

    code {
        font-family: Consolas, Monaco, 'Courier New', monospace;
        background-color: #f1f5f9;
        padding: 2px 5px;
        border-radius: 4px;
        font-size: 9.5pt;
    }

    pre code {
        background-color: transparent;
        padding: 0;
        font-size: 10pt;
    }

    /* Placeholders de capture d'écran */
    .screenshot-placeholder {
        background: #fdf2f8;
        border: 2px dashed #db2777;
        border-radius: 8px;
        padding: 20px;
        margin: 2em 0;
        text-align: center;
        font-family: var(--font-sans);
        font-size: 10.5pt;
        color: #be185d;
        page-break-inside: avoid;
    }
    
    .screenshot-placeholder h5 {
        margin: 0 0 8px 0;
        color: #be185d;
        font-size: 11pt;
        text-transform: uppercase;
        font-weight: 700;
    }
    
    .screenshot-placeholder p {
        text-align: center;
        text-indent: 0;
        margin: 0;
        font-style: italic;
    }

    /* Panneau d'actions flottant */
    .action-panel {
        position: fixed;
        bottom: 30px;
        right: 30px;
        display: flex;
        flex-direction: column;
        gap: 10px;
        z-index: 1000;
        font-family: var(--font-sans);
    }

    .action-button {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 10px 20px;
        border-radius: 50px;
        font-weight: 600;
        font-size: 10pt;
        cursor: pointer;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        transition: all 0.2s ease;
        text-decoration: none;
        border: none;
    }

    .action-button:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 18px rgba(0,0,0,0.22);
    }

    .btn-pdf {
        background-color: #dc2626; /* Rouge PDF */
        color: white;
    }
    .btn-pdf:hover {
        background-color: #b91c1c;
    }

    .btn-word {
        background-color: #2563eb; /* Bleu Word */
        color: white;
    }
    .btn-word:hover {
        background-color: #1d4ed8;
    }

    .btn-print {
        background-color: #0d9488; /* Vert Émeraude */
        color: white;
    }
    .btn-print:hover {
        background-color: #0f766e;
    }

    .action-button svg {
        width: 16px;
        height: 16px;
        fill: currentColor;
    }

    /* Style spécifique pour Mermaid UML */
    .mermaid {
        display: flex;
        justify-content: center;
        margin: 2em 0;
        background: #fafafa;
        padding: 20px;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        page-break-inside: avoid;
        width: 100%;
        overflow-x: auto;
    }
    
    .mermaid svg {
        max-width: 100% !important;
        height: auto;
    }
    </css_styles>
    """

    # Ajout du script Mermaid pour le rendu automatique des diagrammes
    mermaid_script = """
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <script>
        mermaid.initialize({
            startOnLoad: true,
            theme: 'default',
            securityLevel: 'loose',
            flowchart: { useWidth: true, htmlLabels: true },
            sequence: { useWidth: true }
        });
    </script>
    """

    # Post-traitement du HTML pour transformer les blocs de code mermaid en divs réels
    # Et formater les placeholders de captures
    import re
    
    # 1. Remplacer les blocs de code mermaid par des divs avec classe .mermaid
    html_body = re.sub(
        r'<pre[^>]*><code class="(?:language-)?mermaid">([\s\S]*?)<\/code><\/pre>',
        r'<div class="mermaid">\1</div>',
        html_body
    )
    
    # 2. Formater les placeholders de captures d'écran
    # Recherche les blocs comme [EMPLACEMENT DES CAPTURES D'ÉCRAN...] et les transforme en jolis encadrés
    def format_screenshot(match):
        content = match.group(1).strip()
        lines = content.split('\n')
        title = lines[0] if lines else "EMPLACEMENT DE CAPTURE D'ÉCRAN"
        details = "<br>".join(lines[1:]) if len(lines) > 1 else ""
        return f'''
        <div class="screenshot-placeholder">
            <h5>{title}</h5>
            <p>{details}</p>
        </div>
        '''

    html_body = re.sub(
        r'<pre><code>\[(EMPLACEMENT[\s\S]*?)\]<\/code><\/pre>',
        format_screenshot,
        html_body
    )

    # 3. Ajouter des sauts de page automatiques avant chaque chapitre principal (h2)
    # Dans le mémoire, chaque h2 commence par "CHAPITRE" ou "INTRODUCTION" ou "BIBLIOGRAPHIE"
    def add_page_breaks(match):
        heading = match.group(0)
        content = match.group(1)
        if "CHAPITRE" in content or "INTRODUCTION" in content or "BIBLIOGRAPHIE" in content or "CONCLUSION" in content:
            return f'<div class="page-break"></div>\n{heading}'
        return heading

    html_body = re.sub(
        r'(<h2[^>]*>(.*?)<\/h2>)',
        add_page_breaks,
        html_body
    )

    # Assembler le document HTML final
    full_html = f"""<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mémoire - Djorssi-Match</title>
    <style>
        {css_styles}
    </style>
</head>
<body>
    <div class="action-panel no-print">
        <a class="action-button btn-pdf" href="memoire_complet.pdf" download="memoire_complet.pdf" title="Télécharger le mémoire au format PDF officiel">
            <svg viewBox="0 0 24 24">
                <path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/>
            </svg>
            Télécharger le PDF
        </a>
        <a class="action-button btn-word" href="memoire_complet.docx" download="memoire_complet.docx" title="Télécharger le mémoire au format Microsoft Word">
            <svg viewBox="0 0 24 24">
                <path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/>
            </svg>
            Télécharger en Word (.docx)
        </a>
        <button class="action-button btn-print" onclick="window.print()" title="Imprimer ou enregistrer manuellement le mémoire">
            <svg viewBox="0 0 24 24">
                <path d="M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z"/>
            </svg>
            Imprimer / PDF Manuel
        </button>
    </div>

    <div class="memoire-container">
        {html_body}
    </div>

    {mermaid_script}
</body>
</html>
"""

    print(f"Écriture du mémoire compilé dans : {html_path}")
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(full_html)
        
    print("Compilation terminée avec succès !")
    return True

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))
    md_file = os.path.join(base_dir, "memoire_complet.md")
    html_file = os.path.join(base_dir, "memoire_complet.html")
    
    success = compile_markdown_to_html(md_file, html_file)
    if success:
        print(f"Vous pouvez maintenant ouvrir le fichier suivant dans votre navigateur :\\n{html_file}")
        print("Cliquez sur le bouton bleu flottant 'Exporter en PDF / Imprimer' pour générer votre mémoire final !")
