import json
import os
import re

def clean_phone(phone):
    if not phone: return ""
    cleaned = re.sub(r'[^0-9]', '', str(phone))
    if len(cleaned) == 10:
        return f"225{cleaned}"
    elif len(cleaned) == 8:
        return f"22507{cleaned}"
    return cleaned

def escape_sql(text):
    if text is None:
        return "NULL"
    if isinstance(text, bool):
        return str(text).lower()
    if isinstance(text, list):
        # Format as PostgreSQL ARRAY['val1', 'val2']
        elements = ["'{}'".format(str(e).replace("'", "''")) for e in text]
        return "ARRAY[{}]".format(", ".join(elements))
    
    # Escape single quotes
    escaped = str(text).replace("'", "''")
    return f"'{escaped}'"

def generate_sql(json_path, output_path):
    if not os.path.exists(json_path):
        print(f"❌ Fichier non trouvé : {json_path}")
        return

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    sql_lines = []
    # sql_lines.append("-- SQL Insert Script for Extraction 6")
    
    for i, item in enumerate(data):
        source_url = item.get("urls")
        if not source_url:
            source_url = f"extraction6_id_{i}"

        # Mapping
        job_title = escape_sql(item.get("title", "Sans titre"))
        company_name = escape_sql(item.get("company_name") or "Non précisé")
        description = escape_sql(item.get("summary", ""))
        deadline = escape_sql(item.get("deadline"))
        required_level = escape_sql(item.get("niveau"))
        location = escape_sql(item.get("lieu", "Côte d'Ivoire"))
        url = escape_sql(source_url)
        is_ai_verified = "true"
        tags = escape_sql(item.get("tags", []))
        contact_email = escape_sql(item.get("email"))
        whatsapp_number = escape_sql(clean_phone(item.get("contact")))
        app_instructions = escape_sql(item.get("objet"))
        app_link = escape_sql(item.get("urls"))
        requires_cl = "true" if item.get("lettre_motivation") == "OUI" else "false"
        cl_instructions = escape_sql(item.get("lettre_motivation"))
        raw_data = escape_sql(json.dumps(item))

        sql = f"""INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    {job_title}, {company_name}, {url}, {deadline}, {required_level}, 
    {description}, {app_instructions}, {app_link}, 
    {whatsapp_number}, {contact_email}, {is_ai_verified}, {location}, {tags}, 
    {requires_cl}, {cl_instructions}, {raw_data}
) ON CONFLICT (source_url) DO UPDATE SET
    job_title = EXCLUDED.job_title,
    company_name = EXCLUDED.company_name,
    description = EXCLUDED.description,
    deadline = EXCLUDED.deadline,
    required_level = EXCLUDED.required_level,
    location = EXCLUDED.location,
    tags = EXCLUDED.tags,
    contact_email = EXCLUDED.contact_email,
    whatsapp_number = EXCLUDED.whatsapp_number,
    application_instructions = EXCLUDED.application_instructions,
    application_link = EXCLUDED.application_link,
    requires_cover_letter = EXCLUDED.requires_cover_letter,
    cover_letter_instructions = EXCLUDED.cover_letter_instructions,
    raw_data = EXCLUDED.raw_data;"""
        
        sql_lines.append(sql)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("\n\n".join(sql_lines))

    print(f"✅ SQL généré avec succès dans {output_path}")

if __name__ == "__main__":
    JSON_PATH = "/Users/mac/DJORSSI-MATCH/scraper/exaction/extraction6.json"
    OUTPUT_PATH = "/Users/mac/DJORSSI-MATCH/scraper/extraction6.sql"
    generate_sql(JSON_PATH, OUTPUT_PATH)
