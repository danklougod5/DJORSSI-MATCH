import json
import os
import re

def clean_text(text):
    if not text:
        return ""
    # Remplacer les balles bleues 🔹 et autres par des simples tirets ou points
    text = text.replace("🔹", "•")
    text = text.replace("🧩", "-")
    text = text.replace("📢", "!")
    text = text.replace("✅", "OK:")
    text = text.replace("📩", "Contact:")
    text = text.replace("📲", "WhatsApp:")
    text = text.replace("📞", "Tel:")
    text = text.replace("⛔", "X")
    text = text.replace("🚀", ">>")
    # Supprimer les autres emojis/caractères non-ASCII si nécessaire (optionnel mais plus sûr)
    # text = text.encode('ascii', 'ignore').decode('ascii') 
    
    # Nettoyage des apostrophes pour le SQL
    return text.replace("'", "''")

def generate_sql():
    file_path = "/Users/mac/Downloads/offres_djorssi_final (1).json"
    
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    sql_output = "/Users/mac/DJORSSI-MATCH/scraper/insert_all_jobs.sql"
    
    with open(sql_output, 'w', encoding='utf-8') as f:
        f.write("-- 1. Nettoyage de la table\n")
        f.write("DELETE FROM public.jobs;\n\n")
        f.write("ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS application_link TEXT;\n")
        f.write("ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS application_instructions TEXT;\n\n")
        
        f.write("INSERT INTO public.jobs (\n")
        f.write("    job_title, company_name, source_url, deadline, required_level, \n")
        f.write("    description, application_instructions, application_link, \n")
        f.write("    whatsapp_number, contact_email, is_ai_verified, location, tags, raw_data\n")
        f.write(") VALUES\n")
        
        values_list = []
        for item in data:
            title = clean_text(item.get("title", "Sans titre"))
            company = clean_text(item.get("nom_entreprise", "Non précisé"))
            source_url = (item.get("lien") or "")
            deadline = clean_text(item.get("deadline"))
            level = clean_text(item.get("niveau"))
            description = clean_text(item.get("description"))
            app_instr = clean_text(item.get("dossiers_candidature"))
            
            contact = item.get("contact", {})
            emails = contact.get("emails", [])
            email = clean_text(emails[0] if emails else "")
            
            phones = contact.get("phones", [])
            phone = phones[0] if phones else ""
            phone_clean = re.sub(r'[^0-9]', '', phone)
            if len(phone_clean) == 10: 
                phone_clean = f"225{phone_clean}"
            
            urls = contact.get("urls", [])
            app_link = (urls[0] if urls else "").replace("'", "''")
            
            tags_list = item.get("tags", [])
            if not tags_list:
                tags_sql = "ARRAY[]::TEXT[]"
            else:
                escaped_tags = [t.replace("'", "''") for t in tags_list]
                tags_sql = "ARRAY[" + ", ".join([f"'{t}'" for t in escaped_tags]) + "]"
            
            raw_data_dict = {
                "application_link": app_link,
                "application_instructions": app_instr
            }
            raw_data_json = json.dumps(raw_data_dict).replace("'", "''")
            
            val = (f"('{title}', '{company}', '{source_url}', '{deadline}', '{level}', "
                   f"'{description}', '{app_instr}', '{app_link}', "
                   f"'{phone_clean}', '{email}', true, 'Abidjan', {tags_sql}, '{raw_data_json}')")
            values_list.append(val)
            
        f.write(",\n".join(values_list))
        f.write(";\n")
        
    print(f"✅ SQL script generated (CLEANED) with {len(data)} jobs: {sql_output}")

if __name__ == "__main__":
    generate_sql()
