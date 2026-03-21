import json
import os
import re
import glob

def clean_sql(text):
    if text is None:
        return ""
    text = str(text)
    # Escape single quotes for SQL
    return text.replace("'", "''")

def generate_sql():
    # Find all JSON files in the exaction directory
    exaction_dir = "/Users/mac/DJORSSI-MATCH/scraper/exaction"
    json_files = glob.glob(os.path.join(exaction_dir, "*.json"))
    
    if not json_files:
        print(f"❌ No JSON files found in : {exaction_dir}")
        return

    sql_output = "/Users/mac/DJORSSI-MATCH/scraper/new_data.sql"
    
    seen_urls = set()
    all_values = []
    total_jobs = 0

    for json_file in json_files:
        print(f"📄 Processing {os.path.basename(json_file)}...")
        with open(json_file, 'r', encoding='utf-8') as f:
            try:
                data = json.load(f)
            except Exception as e:
                print(f"❌ Error loading {json_file}: {e}")
                continue
                
        for i, item in enumerate(data):
            title = clean_sql(item.get("title", "Sans titre"))
            company = clean_sql(item.get("company_name", "Non précisé"))
            
            orig_url = item.get("urls") or f"manual_extraction_{total_jobs}"
            source_url = orig_url
            counter = 1
            while source_url in seen_urls:
                source_url = f"{orig_url}_{counter}"
                counter += 1
            seen_urls.add(source_url)
            
            source_url = clean_sql(source_url)
            
            deadline = clean_sql(item.get("deadline"))
            level = clean_sql(item.get("niveau"))
            description = clean_sql(item.get("summary"))
            app_instr = clean_sql(item.get("objet"))
            app_link = clean_sql(item.get("urls"))
            
            email = clean_sql(item.get("email"))
            
            contact_raw = item.get("contact") or ""
            phone_clean = re.sub(r'[^0-9]', '', str(contact_raw))
            if len(phone_clean) == 10: 
                phone_clean = f"225{phone_clean}"
            elif len(phone_clean) == 12 and phone_clean.startswith('225'):
                pass # Already correct
            
            location = clean_sql(item.get("lieu", "Côte d''Ivoire"))
            
            tags_list = item.get("tags", [])
            if not tags_list:
                tags_sql = "ARRAY[]::TEXT[]"
            else:
                escaped_tags = [clean_sql(t) for t in tags_list]
                tags_sql = "ARRAY[" + ", ".join([f"'{t}'" for t in escaped_tags]) + "]"
            
            letter = item.get("lettre_motivation")
            requires_letter = "true" if letter and str(letter).upper() != "NON" else "false"
            letter_instr = clean_sql(letter)
            
            raw_data_json = json.dumps(item).replace("'", "''")
            
            val = (f"('{title}', '{company}', '{source_url}', '{deadline}', '{level}', "
                   f"'{description}', '{app_instr}', '{app_link}', "
                   f"'{phone_clean}', '{email}', true, '{location}', {tags_sql}, "
                   f"{requires_letter}, '{letter_instr}', '{raw_data_json}')")
            all_values.append(val)
            total_jobs += 1

    with open(sql_output, 'w', encoding='utf-8') as f:
        f.write("-- 1. Nettoyage de la table\n")
        f.write("DELETE FROM public.jobs;\n\n")
        
        # Ensure columns exist (just in case)
        f.write("ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS application_link TEXT;\n")
        f.write("ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS application_instructions TEXT;\n")
        f.write("ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS requires_cover_letter BOOLEAN DEFAULT FALSE;\n")
        f.write("ALTER TABLE public.jobs ADD COLUMN IF NOT EXISTS cover_letter_instructions TEXT;\n\n")
        
        f.write("INSERT INTO public.jobs (\n")
        f.write("    job_title, company_name, source_url, deadline, required_level, \n")
        f.write("    description, application_instructions, application_link, \n")
        f.write("    whatsapp_number, contact_email, is_ai_verified, location, tags, \n")
        f.write("    requires_cover_letter, cover_letter_instructions, raw_data\n")
        f.write(") VALUES\n")
        
        f.write(",\n".join(all_values))
        f.write(";\n")
        
    print(f"✅ SQL script generated with {total_jobs} jobs from {len(json_files)} files: {sql_output}")

if __name__ == "__main__":
    generate_sql()
