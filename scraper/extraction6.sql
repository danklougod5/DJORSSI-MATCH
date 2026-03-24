INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Responsable HSE (H/F)', 'GRB Burkina (pour client)', 'extraction6_id_0', NULL, 'BAC+3, BAC+4, BAC+5', 
    'Poste de Responsable HSE. Exigences : Bac+3/5 en HSE, Qualité, Environnement ; 3 à 5 ans d’expérience en gestion HSE (industrie, logistique, minier) ; connaissance des réglementations locales et internationales ; compétences en management d’équipe. Basé à Ouagadougou, Burkina Faso.', 'mention du poste', NULL, 
    '', 'contact@grbrh.com, farouk@grbrh.com', true, 'Burkina Faso, Ouagadougou', ARRAY['HSE', 'Sécurité', 'Environnement', 'Qualité', 'Industrie'], 
    true, 'OUI', '{"title": "Responsable HSE (H/F)", "company_name": "GRB Burkina (pour client)", "summary": "Poste de Responsable HSE. Exigences : Bac+3/5 en HSE, Qualit\u00e9, Environnement ; 3 \u00e0 5 ans d\u2019exp\u00e9rience en gestion HSE (industrie, logistique, minier) ; connaissance des r\u00e9glementations locales et internationales ; comp\u00e9tences en management d\u2019\u00e9quipe. Bas\u00e9 \u00e0 Ouagadougou, Burkina Faso.", "contact": null, "lettre_motivation": "OUI", "objet": "mention du poste", "urls": null, "email": "contact@grbrh.com, farouk@grbrh.com", "deadline": null, "niveau": "BAC+3, BAC+4, BAC+5", "lieu": "Burkina Faso, Ouagadougou", "tags": ["HSE", "S\u00e9curit\u00e9", "Environnement", "Qualit\u00e9", "Industrie"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Responsable Projets IT', 'AGILLY', 'extraction6_id_1', NULL, NULL, 
    'Pilotage de projets IT à fort impact, transformation digitale des entreprises. Rejoignez une équipe dynamique. Envoyer CV et lettre de motivation à recru@agilly.net.', NULL, NULL, 
    '', 'recru@agilly.net', true, NULL, ARRAY['Informatique', 'Gestion de projet', 'Cloud', 'Agile'], 
    true, 'OUI', '{"title": "Responsable Projets IT", "company_name": "AGILLY", "summary": "Pilotage de projets IT \u00e0 fort impact, transformation digitale des entreprises. Rejoignez une \u00e9quipe dynamique. Envoyer CV et lettre de motivation \u00e0 recru@agilly.net.", "contact": null, "lettre_motivation": "OUI", "objet": null, "urls": null, "email": "recru@agilly.net", "deadline": null, "niveau": null, "lieu": null, "tags": ["Informatique", "Gestion de projet", "Cloud", "Agile"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Contrôleur Financier / Comptable (H/F)', 'Total Emploi RH', 'extraction6_id_2', '30/03/2026', NULL, 
    'Expérience requise : 3 ans. Date limite : 30/03/2026. Postulez via email.', NULL, NULL, 
    '237233430041673722341', 'info@total-emploirh.com', true, NULL, ARRAY['Contrôle de gestion', 'Comptabilité', 'Finance'], 
    false, NULL, '{"title": "Contr\u00f4leur Financier / Comptable (H/F)", "company_name": "Total Emploi RH", "summary": "Exp\u00e9rience requise : 3 ans. Date limite : 30/03/2026. Postulez via email.", "contact": "+237 233 43 00 41 / 673 72 23 41", "lettre_motivation": null, "objet": null, "urls": null, "email": "info@total-emploirh.com", "deadline": "30/03/2026", "niveau": null, "lieu": null, "tags": ["Contr\u00f4le de gestion", "Comptabilit\u00e9", "Finance"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'CHARGÉ DE L’ADMINISTRATION RH (spécialisation PAIE)', 'Banque Atlantique Côte d’Ivoire', 'https://lnkd.in/evaJ-si', '27/03/2026', NULL, 
    'Poste en CDI. Envoyer CV + lettre de motivation à recrutement.baci@BANQUEATLANTIQUE.NET. Date limite : 27 mars 2026. Plus d’informations sur le lien.', NULL, 'https://lnkd.in/evaJ-si', 
    '', 'recrutement.baci@BANQUEATLANTIQUE.NET', true, NULL, ARRAY['RH', 'Paie', 'Banque'], 
    true, 'OUI', '{"title": "CHARG\u00c9 DE L\u2019ADMINISTRATION RH (sp\u00e9cialisation PAIE)", "company_name": "Banque Atlantique C\u00f4te d\u2019Ivoire", "summary": "Poste en CDI. Envoyer CV + lettre de motivation \u00e0 recrutement.baci@BANQUEATLANTIQUE.NET. Date limite : 27 mars 2026. Plus d\u2019informations sur le lien.", "contact": null, "lettre_motivation": "OUI", "objet": null, "urls": "https://lnkd.in/evaJ-si", "email": "recrutement.baci@BANQUEATLANTIQUE.NET", "deadline": "27/03/2026", "niveau": null, "lieu": null, "tags": ["RH", "Paie", "Banque"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Assistant(e) Commercial(e)', 'FeexPay', 'extraction6_id_4', NULL, NULL, 
    'Soutenir l’équipe commerciale, développement des partenariats. Poste basé à Cotonou, temps plein. Envoyer CV à recrutement@lavedette.net.', NULL, NULL, 
    '', 'recrutement@lavedette.net', true, 'Cotonou', ARRAY['Commerce', 'Assistanat commercial', 'Fintech'], 
    false, NULL, '{"title": "Assistant(e) Commercial(e)", "company_name": "FeexPay", "summary": "Soutenir l\u2019\u00e9quipe commerciale, d\u00e9veloppement des partenariats. Poste bas\u00e9 \u00e0 Cotonou, temps plein. Envoyer CV \u00e0 recrutement@lavedette.net.", "contact": null, "lettre_motivation": null, "objet": null, "urls": null, "email": "recrutement@lavedette.net", "deadline": null, "niveau": null, "lieu": "Cotonou", "tags": ["Commerce", "Assistanat commercial", "Fintech"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Assistant Systèmes d’Information (Stage)', 'LE GROUPE ICCNET', 'extraction6_id_5', NULL, 'BAC+3, BAC+4, BAC+5', 
    'Stage à Yaoundé. Missions : assistance à la gestion des infrastructures SI, participation aux projets, support sécurité, gestion des données. Profil : Bac+3/4/5 en Informatique, SI, Réseaux. Envoyer CV à recrutement@iccnet.cm, objet : "Candidature de Stage Assistant SI".', 'Candidature de Stage Assistant SI', NULL, 
    '', 'recrutement@iccnet.cm', true, 'Yaoundé', ARRAY['Stage', 'Informatique', 'Systèmes d''information', 'Réseaux'], 
    false, NULL, '{"title": "Assistant Syst\u00e8mes d\u2019Information (Stage)", "company_name": "LE GROUPE ICCNET", "summary": "Stage \u00e0 Yaound\u00e9. Missions : assistance \u00e0 la gestion des infrastructures SI, participation aux projets, support s\u00e9curit\u00e9, gestion des donn\u00e9es. Profil : Bac+3/4/5 en Informatique, SI, R\u00e9seaux. Envoyer CV \u00e0 recrutement@iccnet.cm, objet : \"Candidature de Stage Assistant SI\".", "contact": null, "lettre_motivation": null, "objet": "Candidature de Stage Assistant SI", "urls": null, "email": "recrutement@iccnet.cm", "deadline": null, "niveau": "BAC+3, BAC+4, BAC+5", "lieu": "Yaound\u00e9", "tags": ["Stage", "Informatique", "Syst\u00e8mes d''information", "R\u00e9seaux"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Chargé(e) de l’Insertion Professionnelle des Étudiants (H/F)', 'EMPOWER Talents & Careers', 'https://lnkd.in/eEsCReDh', NULL, 'BAC+3, BAC+4, BAC+5', 
    'Poste pour un client de l’enseignement supérieur. Profil : Bac+3/5 en RH, sciences sociales, psychologie, sociologie, gestion, orientation ; 2-3 ans d’expérience en insertion, employabilité. Dossier : CV uniquement. Postuler via lien, objet : CHARGÉ(E) DE L’INSERTION PROFESSIONNELLE DES ÉTUDIANTS (H/F).', 'CHARGÉ(E) DE L’INSERTION PROFESSIONNELLE DES ÉTUDIANTS (H/F)', 'https://lnkd.in/eEsCReDh', 
    '2250502138383', NULL, true, NULL, ARRAY['Insertion professionnelle', 'RH', 'Orientation', 'Accompagnement'], 
    false, NULL, '{"title": "Charg\u00e9(e) de l\u2019Insertion Professionnelle des \u00c9tudiants (H/F)", "company_name": "EMPOWER Talents & Careers", "summary": "Poste pour un client de l\u2019enseignement sup\u00e9rieur. Profil : Bac+3/5 en RH, sciences sociales, psychologie, sociologie, gestion, orientation ; 2-3 ans d\u2019exp\u00e9rience en insertion, employabilit\u00e9. Dossier : CV uniquement. Postuler via lien, objet : CHARG\u00c9(E) DE L\u2019INSERTION PROFESSIONNELLE DES \u00c9TUDIANTS (H/F).", "contact": "(+225) 05 02 13 83 83 (WhatsApp)", "lettre_motivation": null, "objet": "CHARG\u00c9(E) DE L\u2019INSERTION PROFESSIONNELLE DES \u00c9TUDIANTS (H/F)", "urls": "https://lnkd.in/eEsCReDh", "email": null, "deadline": null, "niveau": "BAC+3, BAC+4, BAC+5", "lieu": null, "tags": ["Insertion professionnelle", "RH", "Orientation", "Accompagnement"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Gestionnaire Assurance Santé (H/F)', 'Nouvelle Parfumerie Gandour CI', 'extraction6_id_7', NULL, NULL, 
    'Postulez en envoyant votre CV à recrutements@npgandour.com.', NULL, NULL, 
    '', 'recrutements@npgandour.com', true, NULL, ARRAY['Assurance santé', 'Gestion'], 
    false, NULL, '{"title": "Gestionnaire Assurance Sant\u00e9 (H/F)", "company_name": "Nouvelle Parfumerie Gandour CI", "summary": "Postulez en envoyant votre CV \u00e0 recrutements@npgandour.com.", "contact": null, "lettre_motivation": null, "objet": null, "urls": null, "email": "recrutements@npgandour.com", "deadline": null, "niveau": null, "lieu": null, "tags": ["Assurance sant\u00e9", "Gestion"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Assistante administrative (2 postes)', 'Entreprise immobilière (Cocody)', 'extraction6_id_8', NULL, NULL, 
    'Salaire : 500 000 F CFA. Missions : gestion administrative, suivi clients, coordination, assistance direction. Profil : bilingue (français/anglais), excellente présentation, maîtrise bureautique, organisation. Postuler à talents.maestra@outlook.com.', NULL, NULL, 
    '', 'talents.maestra@outlook.com', true, 'Cocody, Abidjan', ARRAY['Assistanat', 'Bilingue', 'Immobilier'], 
    false, NULL, '{"title": "Assistante administrative (2 postes)", "company_name": "Entreprise immobili\u00e8re (Cocody)", "summary": "Salaire : 500 000 F CFA. Missions : gestion administrative, suivi clients, coordination, assistance direction. Profil : bilingue (fran\u00e7ais/anglais), excellente pr\u00e9sentation, ma\u00eetrise bureautique, organisation. Postuler \u00e0 talents.maestra@outlook.com.", "contact": null, "lettre_motivation": null, "objet": null, "urls": null, "email": "talents.maestra@outlook.com", "deadline": null, "niveau": null, "lieu": "Cocody, Abidjan", "tags": ["Assistanat", "Bilingue", "Immobilier"], "salary_range": "500 000 F CFA"}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Consultant(e) National(e) – Expert(e) en droit et en genre', 'ONU Femmes Côte d’Ivoire', 'https://urls.fr/y0bAuS', '03/04/2026', NULL, 
    'Appui à l’élaboration participative d’un projet d’arrêté ministériel. Postuler via le lien. Date limite : 03 avril 2026.', NULL, 'https://urls.fr/y0bAuS', 
    '', NULL, true, NULL, ARRAY['Droit', 'Genre', 'Consultant', 'ONU'], 
    false, NULL, '{"title": "Consultant(e) National(e) \u2013 Expert(e) en droit et en genre", "company_name": "ONU Femmes C\u00f4te d\u2019Ivoire", "summary": "Appui \u00e0 l\u2019\u00e9laboration participative d\u2019un projet d\u2019arr\u00eat\u00e9 minist\u00e9riel. Postuler via le lien. Date limite : 03 avril 2026.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://urls.fr/y0bAuS", "email": null, "deadline": "03/04/2026", "niveau": null, "lieu": null, "tags": ["Droit", "Genre", "Consultant", "ONU"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Assistant Juridique (H/F)', 'Elite Intérim Côte d''Ivoire', 'extraction6_id_10', NULL, 'BAC+2, BAC+3, BAC+4, BAC+5', 
    'Missions : suivi administratif des dossiers juridiques, rédaction, gestion des contrats, veille juridique. Profil : Bac+2 à Bac+5 en Droit, connaissance droit ivoirien/OHADA, rédaction, bureautique. Postuler à service.recrutement@eliteinterim.ci ou recrutement@eliteinterim.ci avec objet "Assistant Juridique".', 'Assistant Juridique', NULL, 
    '', 'service.recrutement@eliteinterim.ci, recrutement@eliteinterim.ci', true, 'Abidjan', ARRAY['Juridique', 'Droit', 'Assistant juridique'], 
    false, NULL, '{"title": "Assistant Juridique (H/F)", "company_name": "Elite Int\u00e9rim C\u00f4te d''Ivoire", "summary": "Missions : suivi administratif des dossiers juridiques, r\u00e9daction, gestion des contrats, veille juridique. Profil : Bac+2 \u00e0 Bac+5 en Droit, connaissance droit ivoirien/OHADA, r\u00e9daction, bureautique. Postuler \u00e0 service.recrutement@eliteinterim.ci ou recrutement@eliteinterim.ci avec objet \"Assistant Juridique\".", "contact": null, "lettre_motivation": null, "objet": "Assistant Juridique", "urls": null, "email": "service.recrutement@eliteinterim.ci, recrutement@eliteinterim.ci", "deadline": null, "niveau": "BAC+2, BAC+3, BAC+4, BAC+5", "lieu": "Abidjan", "tags": ["Juridique", "Droit", "Assistant juridique"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Agent de recouvrement amiable (Stage d’adaptation)', 'CREDIT MUTUEL DU SENEGAL', 'extraction6_id_11', '25/03/2026', NULL, 
    'Envoyer CV à cmsrecrutement@cms.sn avant le 25 mars 2026 à 17h.', NULL, NULL, 
    '', 'cmsrecrutement@cms.sn', true, NULL, ARRAY['Recouvrement', 'Stage', 'Microfinance'], 
    false, NULL, '{"title": "Agent de recouvrement amiable (Stage d\u2019adaptation)", "company_name": "CREDIT MUTUEL DU SENEGAL", "summary": "Envoyer CV \u00e0 cmsrecrutement@cms.sn avant le 25 mars 2026 \u00e0 17h.", "contact": null, "lettre_motivation": null, "objet": null, "urls": null, "email": "cmsrecrutement@cms.sn", "deadline": "25/03/2026", "niveau": null, "lieu": null, "tags": ["Recouvrement", "Stage", "Microfinance"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Commercial (F/H)', 'RMO_TOGO', 'https://lnkd.in/eKpJqBVF', NULL, NULL, 
    'Postuler via le lien : https://lnkd.in/eKpJqBVF.', NULL, 'https://lnkd.in/eKpJqBVF', 
    '', NULL, true, NULL, ARRAY['Commerce', 'Vente'], 
    false, NULL, '{"title": "Commercial (F/H)", "company_name": "RMO_TOGO", "summary": "Postuler via le lien : https://lnkd.in/eKpJqBVF.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/eKpJqBVF", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["Commerce", "Vente"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Chef(fe) de Service Achat CAPEX', 'SUCRIVOIRE (Groupe SIFCA)', 'https://lnkd.in/ebRBpEzB', NULL, NULL, 
    'Consultez l’offre complète : https://lnkd.in/ebRBpEzB.', NULL, 'https://lnkd.in/ebRBpEzB', 
    '', NULL, true, NULL, ARRAY['Achats', 'CAPEX', 'Agro-industrie'], 
    false, NULL, '{"title": "Chef(fe) de Service Achat CAPEX", "company_name": "SUCRIVOIRE (Groupe SIFCA)", "summary": "Consultez l\u2019offre compl\u00e8te : https://lnkd.in/ebRBpEzB.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/ebRBpEzB", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["Achats", "CAPEX", "Agro-industrie"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Électricien en Bâtiment', 'Elite Intérim Côte d''Ivoire', 'extraction6_id_14', NULL, 'CAP, BEP, BT, BAC', 
    'Missions : installations électriques, maintenance, lecture plans, sécurité. Profil : CAP/BEP/BT/BAC Pro Électricité Bâtiment, 3 ans expérience, maîtrise BT, normes. Postuler à service.recrutement@eliteinterim.ci ou recrutement@eliteinterim.ci, objet "Électricien Bâtiment".', 'Électricien Bâtiment', NULL, 
    '', 'service.recrutement@eliteinterim.ci, recrutement@eliteinterim.ci', true, 'Côte d’Ivoire', ARRAY['Électricité', 'Bâtiment', 'BTP'], 
    false, NULL, '{"title": "\u00c9lectricien en B\u00e2timent", "company_name": "Elite Int\u00e9rim C\u00f4te d''Ivoire", "summary": "Missions : installations \u00e9lectriques, maintenance, lecture plans, s\u00e9curit\u00e9. Profil : CAP/BEP/BT/BAC Pro \u00c9lectricit\u00e9 B\u00e2timent, 3 ans exp\u00e9rience, ma\u00eetrise BT, normes. Postuler \u00e0 service.recrutement@eliteinterim.ci ou recrutement@eliteinterim.ci, objet \"\u00c9lectricien B\u00e2timent\".", "contact": null, "lettre_motivation": null, "objet": "\u00c9lectricien B\u00e2timent", "urls": null, "email": "service.recrutement@eliteinterim.ci, recrutement@eliteinterim.ci", "deadline": null, "niveau": "CAP, BEP, BT, BAC", "lieu": "C\u00f4te d\u2019Ivoire", "tags": ["\u00c9lectricit\u00e9", "B\u00e2timent", "BTP"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Conseiller en éducation', 'GOMYCODE', 'https://lnkd.in/er2vGMv9', NULL, NULL, 
    'Profil : excellent relationnel, fibre commerciale, affinité pour la Tech. Postulez via https://lnkd.in/er2vGMv9.', NULL, 'https://lnkd.in/er2vGMv9', 
    '', NULL, true, NULL, ARRAY['Conseiller', 'Éducation', 'Tech', 'Vente'], 
    false, NULL, '{"title": "Conseiller en \u00e9ducation", "company_name": "GOMYCODE", "summary": "Profil : excellent relationnel, fibre commerciale, affinit\u00e9 pour la Tech. Postulez via https://lnkd.in/er2vGMv9.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/er2vGMv9", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["Conseiller", "\u00c9ducation", "Tech", "Vente"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Humanitarian Operations Advisor WCA', 'Save the Children Côte d''Ivoire', 'https://lnkd.in/egVVyDFF (interne), https://lnkd.in/eyE6HCyJ (externe)', '23/03/2026', NULL, 
    'Postuler via liens interne/externe. Date limite : 23/03/2026 à 23h59.', NULL, 'https://lnkd.in/egVVyDFF (interne), https://lnkd.in/eyE6HCyJ (externe)', 
    '', NULL, true, NULL, ARRAY['Humanitaire', 'Opérations', 'ONG'], 
    false, NULL, '{"title": "Humanitarian Operations Advisor WCA", "company_name": "Save the Children C\u00f4te d''Ivoire", "summary": "Postuler via liens interne/externe. Date limite : 23/03/2026 \u00e0 23h59.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/egVVyDFF (interne), https://lnkd.in/eyE6HCyJ (externe)", "email": null, "deadline": "23/03/2026", "niveau": null, "lieu": null, "tags": ["Humanitaire", "Op\u00e9rations", "ONG"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Directeur(trice) Général(e) Adjoint(e)', 'AT225', 'https://lnkd.in/eHprSjzZ', NULL, 'BAC+5', 
    'Secteur événementiel. Profil : Bac+5 en École de Commerce, Ingénierie, Master Management ; 10 ans expérience ; maîtrise enjeux financiers. Postulez via https://lnkd.in/eHprSjzZ.', NULL, 'https://lnkd.in/eHprSjzZ', 
    '', NULL, true, NULL, ARRAY['Direction générale', 'Événementiel', 'Management'], 
    false, NULL, '{"title": "Directeur(trice) G\u00e9n\u00e9ral(e) Adjoint(e)", "company_name": "AT225", "summary": "Secteur \u00e9v\u00e9nementiel. Profil : Bac+5 en \u00c9cole de Commerce, Ing\u00e9nierie, Master Management ; 10 ans exp\u00e9rience ; ma\u00eetrise enjeux financiers. Postulez via https://lnkd.in/eHprSjzZ.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/eHprSjzZ", "email": null, "deadline": null, "niveau": "BAC+5", "lieu": null, "tags": ["Direction g\u00e9n\u00e9rale", "\u00c9v\u00e9nementiel", "Management"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'CHARGÉ(E) CLIENTÈLE', 'SAAR VIE COTE D''IVOIRE', 'extraction6_id_18', '25/03/2026', 'BTS', 
    'BTS minimum. Formation obligatoire 3 mois à Abidjan, puis déploiement dans plusieurs villes. Envoyer CV à recrutement.saarvie@saarassurancesci.com, objet : "Chargée Clientèle + Localité + 19032026". Date limite : 25 mars 2026.', 'Chargée Clientèle + Localité + 19032026', NULL, 
    '', 'recrutement.saarvie@saarassurancesci.com', true, 'Abidjan (formation), puis plusieurs villes', ARRAY['Chargé clientèle', 'Assurance', 'Relation client'], 
    false, NULL, '{"title": "CHARG\u00c9(E) CLIENT\u00c8LE", "company_name": "SAAR VIE COTE D''IVOIRE", "summary": "BTS minimum. Formation obligatoire 3 mois \u00e0 Abidjan, puis d\u00e9ploiement dans plusieurs villes. Envoyer CV \u00e0 recrutement.saarvie@saarassurancesci.com, objet : \"Charg\u00e9e Client\u00e8le + Localit\u00e9 + 19032026\". Date limite : 25 mars 2026.", "contact": null, "lettre_motivation": null, "objet": "Charg\u00e9e Client\u00e8le + Localit\u00e9 + 19032026", "urls": null, "email": "recrutement.saarvie@saarassurancesci.com", "deadline": "25/03/2026", "niveau": "BTS", "lieu": "Abidjan (formation), puis plusieurs villes", "tags": ["Charg\u00e9 client\u00e8le", "Assurance", "Relation client"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Gestionnaire Chargé du Contentieux (H/F)', 'NSIA Banque Cote d''Ivoire', 'https://lnkd.in/ez6ae9CN', NULL, NULL, 
    'Consultez les annonces sur le site : https://lnkd.in/ez6ae9CN.', NULL, 'https://lnkd.in/ez6ae9CN', 
    '', NULL, true, NULL, ARRAY['Contentieux', 'Banque', 'Gestion'], 
    false, NULL, '{"title": "Gestionnaire Charg\u00e9 du Contentieux (H/F)", "company_name": "NSIA Banque Cote d''Ivoire", "summary": "Consultez les annonces sur le site : https://lnkd.in/ez6ae9CN.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/ez6ae9CN", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["Contentieux", "Banque", "Gestion"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'CHEF DE DÉPARTEMENT SERVICES GÉNÉRAUX (H/F)', 'Le CIFIP (secteur bancaire)', 'extraction6_id_20', NULL, 'BAC+4, BAC+5', 
    'Missions : piloter logistique, approvisionnements, fournisseurs, archives, budget. Profil : Bac+4/5 Logistique, Gestion, Finance ; 7 ans expérience. Envoyer CV & prétentions salariales à recrutement@cifip-ci.com.', NULL, NULL, 
    '', 'recrutement@cifip-ci.com', true, NULL, ARRAY['Services généraux', 'Logistique', 'Gestion', 'Banque'], 
    false, NULL, '{"title": "CHEF DE D\u00c9PARTEMENT SERVICES G\u00c9N\u00c9RAUX (H/F)", "company_name": "Le CIFIP (secteur bancaire)", "summary": "Missions : piloter logistique, approvisionnements, fournisseurs, archives, budget. Profil : Bac+4/5 Logistique, Gestion, Finance ; 7 ans exp\u00e9rience. Envoyer CV & pr\u00e9tentions salariales \u00e0 recrutement@cifip-ci.com.", "contact": null, "lettre_motivation": null, "objet": null, "urls": null, "email": "recrutement@cifip-ci.com", "deadline": null, "niveau": "BAC+4, BAC+5", "lieu": null, "tags": ["Services g\u00e9n\u00e9raux", "Logistique", "Gestion", "Banque"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Contracts Officer H/F', 'Upright Partners (pour société minière)', 'https://lnkd.in/dEafwT5r', '23/03/2026', 'BAC+3', 
    'Profil : Bac+3 en droit, supply chain, gestion, économie ; 3-5 ans expérience ; maîtrise SAP ; connaissance contenu local. Besoin urgent, deadline 23 mars 2026. Postuler via https://lnkd.in/dEafwT5r.', NULL, 'https://lnkd.in/dEafwT5r', 
    '', NULL, true, 'Abidjan', ARRAY['Contracts', 'Achats', 'Mines', 'Droit', 'SAP'], 
    false, NULL, '{"title": "Contracts Officer H/F", "company_name": "Upright Partners (pour soci\u00e9t\u00e9 mini\u00e8re)", "summary": "Profil : Bac+3 en droit, supply chain, gestion, \u00e9conomie ; 3-5 ans exp\u00e9rience ; ma\u00eetrise SAP ; connaissance contenu local. Besoin urgent, deadline 23 mars 2026. Postuler via https://lnkd.in/dEafwT5r.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/dEafwT5r", "email": null, "deadline": "23/03/2026", "niveau": "BAC+3", "lieu": "Abidjan", "tags": ["Contracts", "Achats", "Mines", "Droit", "SAP"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Responsable Administration des Achats', 'SUCRIVOIRE (Groupe SIFCA)', 'https://lnkd.in/e7xG6BeJ', NULL, NULL, 
    'Consultez l’offre : https://lnkd.in/e7xG6BeJ.', NULL, 'https://lnkd.in/e7xG6BeJ', 
    '', NULL, true, NULL, ARRAY['Achats', 'Administration', 'Agro-industrie'], 
    false, NULL, '{"title": "Responsable Administration des Achats", "company_name": "SUCRIVOIRE (Groupe SIFCA)", "summary": "Consultez l\u2019offre : https://lnkd.in/e7xG6BeJ.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/e7xG6BeJ", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["Achats", "Administration", "Agro-industrie"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Responsable Investissement Immobilier H/F', 'GPC Groupe (projet KANDARA Real Estate)', 'extraction6_id_23', '03/04/2026', NULL, 
    '5-8 ans expérience, analyse financière immobilière, négociation, stratégie. Poste basé à Conakry. Dossier : lettre de motivation, CV avec 3 références, CNI, certificat résidence, diplômes, attestations. Envoyer à recrutement@gpc-groupe.com, objet : titre du poste. Date limite : 03 avril 2026.', 'titre du poste', NULL, 
    '', 'recrutement@gpc-groupe.com', true, 'Conakry', ARRAY['Immobilier', 'Investissement', 'Finance'], 
    true, 'OUI', '{"title": "Responsable Investissement Immobilier H/F", "company_name": "GPC Groupe (projet KANDARA Real Estate)", "summary": "5-8 ans exp\u00e9rience, analyse financi\u00e8re immobili\u00e8re, n\u00e9gociation, strat\u00e9gie. Poste bas\u00e9 \u00e0 Conakry. Dossier : lettre de motivation, CV avec 3 r\u00e9f\u00e9rences, CNI, certificat r\u00e9sidence, dipl\u00f4mes, attestations. Envoyer \u00e0 recrutement@gpc-groupe.com, objet : titre du poste. Date limite : 03 avril 2026.", "contact": null, "lettre_motivation": "OUI", "objet": "titre du poste", "urls": null, "email": "recrutement@gpc-groupe.com", "deadline": "03/04/2026", "niveau": null, "lieu": "Conakry", "tags": ["Immobilier", "Investissement", "Finance"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Ingénieur Études et Planification (H/F)', 'AT225', 'https://lnkd.in/eJtp22ig', NULL, 'BAC+4, BAC+5', 
    'Secteur BTP. Profil : Bac+4/5 en Génie Civil, Hydraulique, Travaux Publics ; 5-10 ans expérience. Postulez via https://lnkd.in/eJtp22ig.', NULL, 'https://lnkd.in/eJtp22ig', 
    '', NULL, true, NULL, ARRAY['Ingénierie', 'Études', 'Planification', 'BTP', 'Hydraulique'], 
    false, NULL, '{"title": "Ing\u00e9nieur \u00c9tudes et Planification (H/F)", "company_name": "AT225", "summary": "Secteur BTP. Profil : Bac+4/5 en G\u00e9nie Civil, Hydraulique, Travaux Publics ; 5-10 ans exp\u00e9rience. Postulez via https://lnkd.in/eJtp22ig.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/eJtp22ig", "email": null, "deadline": null, "niveau": "BAC+4, BAC+5", "lieu": null, "tags": ["Ing\u00e9nierie", "\u00c9tudes", "Planification", "BTP", "Hydraulique"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Conseillers Clients', 'GROUPE MEDIA CONTACT Côte d’Ivoire', 'extraction6_id_25', '03/04/2026', NULL, 
    'Poste à Abidjan. Sens de l’écoute, relation client. Envoyer CV à gpehou@groupmediacontact.com. Date limite : 03 avril 2026.', NULL, NULL, 
    '', 'gpehou@groupmediacontact.com', true, 'Abidjan', ARRAY['Conseiller client', 'Relation client', 'Centre d''appels'], 
    false, NULL, '{"title": "Conseillers Clients", "company_name": "GROUPE MEDIA CONTACT C\u00f4te d\u2019Ivoire", "summary": "Poste \u00e0 Abidjan. Sens de l\u2019\u00e9coute, relation client. Envoyer CV \u00e0 gpehou@groupmediacontact.com. Date limite : 03 avril 2026.", "contact": null, "lettre_motivation": null, "objet": null, "urls": null, "email": "gpehou@groupmediacontact.com", "deadline": "03/04/2026", "niveau": null, "lieu": "Abidjan", "tags": ["Conseiller client", "Relation client", "Centre d''appels"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Assistant Manager des Opérations Business (H/F)', 'Entreprise internationale industrielle', 'https://lnkd.in/gibEz8Sm', '29/03/2026', 'BAC+3, BAC+4, BAC+5', 
    'Missions : gestion et coordination des opérations business, coordination réglementaire, support administratif. Profil : Bac+3/5 en Administration des Affaires, Commerce, Gestion, Droit des Affaires ; jeunes diplômés acceptés ; français et anglais professionnel. Postuler via https://lnkd.in/gibEz8Sm. Deadline : 29 mars 2026. Dossier : CV, lettre de motivation, prétentions salariales.', NULL, 'https://lnkd.in/gibEz8Sm', 
    '', NULL, true, 'Abidjan', ARRAY['Business operations', 'Assistant manager', 'Industrie'], 
    true, 'OUI', '{"title": "Assistant Manager des Op\u00e9rations Business (H/F)", "company_name": "Entreprise internationale industrielle", "summary": "Missions : gestion et coordination des op\u00e9rations business, coordination r\u00e9glementaire, support administratif. Profil : Bac+3/5 en Administration des Affaires, Commerce, Gestion, Droit des Affaires ; jeunes dipl\u00f4m\u00e9s accept\u00e9s ; fran\u00e7ais et anglais professionnel. Postuler via https://lnkd.in/gibEz8Sm. Deadline : 29 mars 2026. Dossier : CV, lettre de motivation, pr\u00e9tentions salariales.", "contact": null, "lettre_motivation": "OUI", "objet": null, "urls": "https://lnkd.in/gibEz8Sm", "email": null, "deadline": "29/03/2026", "niveau": "BAC+3, BAC+4, BAC+5", "lieu": "Abidjan", "tags": ["Business operations", "Assistant manager", "Industrie"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Bilingual Sales Executive', '2A Consulting', 'extraction6_id_27', '24/03/2026', NULL, 
    'Poste à Abidjan, disponibilité immédiate. Profil : résultats, compétences commerciales, environnement international. Envoyer CV et lettre de motivation à andree.krou@2aconsulting-ci.com, objet : "Application – Bilingual Sales Executive". Deadline : March 24, 2026.', 'Application – Bilingual Sales Executive', NULL, 
    '', 'andree.krou@2aconsulting-ci.com', true, 'Abidjan', ARRAY['Vente', 'Bilingue', 'Anglais', 'Commercial'], 
    true, 'OUI', '{"title": "Bilingual Sales Executive", "company_name": "2A Consulting", "summary": "Poste \u00e0 Abidjan, disponibilit\u00e9 imm\u00e9diate. Profil : r\u00e9sultats, comp\u00e9tences commerciales, environnement international. Envoyer CV et lettre de motivation \u00e0 andree.krou@2aconsulting-ci.com, objet : \"Application \u2013 Bilingual Sales Executive\". Deadline : March 24, 2026.", "contact": null, "lettre_motivation": "OUI", "objet": "Application \u2013 Bilingual Sales Executive", "urls": null, "email": "andree.krou@2aconsulting-ci.com", "deadline": "24/03/2026", "niveau": null, "lieu": "Abidjan", "tags": ["Vente", "Bilingue", "Anglais", "Commercial"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Expert(e) Traitement de fin de journée', 'BGFI Services SIMAO (Groupe BGFI)', 'extraction6_id_28', '24/03/2026', NULL, 
    'Postuler à recrutement_simao@bgfigroupe.com avec CV et lettre de motivation, objet : "Candidature - Expert(e) Traitement de fin de journée". Date limite : 24 mars 2026.', 'Candidature - Expert(e) Traitement de fin de journée', NULL, 
    '', 'recrutement_simao@bgfigroupe.com', true, NULL, ARRAY['Finance', 'Traitement', 'Banque'], 
    true, 'OUI', '{"title": "Expert(e) Traitement de fin de journ\u00e9e", "company_name": "BGFI Services SIMAO (Groupe BGFI)", "summary": "Postuler \u00e0 recrutement_simao@bgfigroupe.com avec CV et lettre de motivation, objet : \"Candidature - Expert(e) Traitement de fin de journ\u00e9e\". Date limite : 24 mars 2026.", "contact": null, "lettre_motivation": "OUI", "objet": "Candidature - Expert(e) Traitement de fin de journ\u00e9e", "urls": null, "email": "recrutement_simao@bgfigroupe.com", "deadline": "24/03/2026", "niveau": null, "lieu": null, "tags": ["Finance", "Traitement", "Banque"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Responsable Administratif et Financier Senior', 'Hemisphere Media Production', 'extraction6_id_29', '31/03/2026', NULL, 
    'Solide expérience en gestion financière et administrative, rigueur, leadership. Postuler avant le 31 mars 2026 à cotonou@hemisphere-africa.com.', NULL, NULL, 
    '', 'cotonou@hemisphere-africa.com', true, NULL, ARRAY['RAF', 'Finance', 'Administration'], 
    false, NULL, '{"title": "Responsable Administratif et Financier Senior", "company_name": "Hemisphere Media Production", "summary": "Solide exp\u00e9rience en gestion financi\u00e8re et administrative, rigueur, leadership. Postuler avant le 31 mars 2026 \u00e0 cotonou@hemisphere-africa.com.", "contact": null, "lettre_motivation": null, "objet": null, "urls": null, "email": "cotonou@hemisphere-africa.com", "deadline": "31/03/2026", "niveau": null, "lieu": null, "tags": ["RAF", "Finance", "Administration"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Auditeur Confirmé', 'UCB (Groupe KADJI)', 'extraction6_id_30', '21/03/2026', NULL, 
    'Poste à Douala. Évaluer contrôle interne, gestion des risques, gouvernance. Envoyer CV PDF à recrutement@sa-ucb.com, objet : AUDINT_032025, deadline 21 mars 2026 à 17H00.', 'AUDINT_032025', NULL, 
    '', 'recrutement@sa-ucb.com', true, 'Douala', ARRAY['Audit', 'Contrôle interne', 'Risques'], 
    false, NULL, '{"title": "Auditeur Confirm\u00e9", "company_name": "UCB (Groupe KADJI)", "summary": "Poste \u00e0 Douala. \u00c9valuer contr\u00f4le interne, gestion des risques, gouvernance. Envoyer CV PDF \u00e0 recrutement@sa-ucb.com, objet : AUDINT_032025, deadline 21 mars 2026 \u00e0 17H00.", "contact": null, "lettre_motivation": null, "objet": "AUDINT_032025", "urls": null, "email": "recrutement@sa-ucb.com", "deadline": "21/03/2026", "niveau": null, "lieu": "Douala", "tags": ["Audit", "Contr\u00f4le interne", "Risques"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'PSSR SENIOR C&I H/F', 'Neemba Guinée', 'extraction6_id_31', '31/03/2026', 'BAC+2, BAC+3', 
    'Missions commerciales et support technique. Profil : BTS/DUT/Licence technique (Mécanique, Electricité, Génie) ; 5 ans expérience ; gestion portefeuille clients ; français, anglais atout. Poste à Conakry. Envoyer CV et lettre de motivation PDF à recrutement.gn@neemba.com, objet : titre du poste. Deadline : 31 mars 2026.', 'PSSR SENIOR C&I', NULL, 
    '', 'recrutement.gn@neemba.com', true, 'Conakry', ARRAY['Commerce', 'Technique', 'Mécanique', 'Guinée'], 
    true, 'OUI', '{"title": "PSSR SENIOR C&I H/F", "company_name": "Neemba Guin\u00e9e", "summary": "Missions commerciales et support technique. Profil : BTS/DUT/Licence technique (M\u00e9canique, Electricit\u00e9, G\u00e9nie) ; 5 ans exp\u00e9rience ; gestion portefeuille clients ; fran\u00e7ais, anglais atout. Poste \u00e0 Conakry. Envoyer CV et lettre de motivation PDF \u00e0 recrutement.gn@neemba.com, objet : titre du poste. Deadline : 31 mars 2026.", "contact": null, "lettre_motivation": "OUI", "objet": "PSSR SENIOR C&I", "urls": null, "email": "recrutement.gn@neemba.com", "deadline": "31/03/2026", "niveau": "BAC+2, BAC+3", "lieu": "Conakry", "tags": ["Commerce", "Technique", "M\u00e9canique", "Guin\u00e9e"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Claim Manager', 'SERVTEC Côte d’Ivoire', 'https://lnkd.in/dGyyQHkb', NULL, 'BAC+5', 
    'Piloter gestion des réclamations, sinistres, analyser risques. Profil : Bac+5 en Génie Civil, Droit, Management de Projets ; 5-10 ans expérience en gestion de claims BTP ; connaissance droit OHADA, contrats FIDIC, NEC. Envoyer CV à recrutement.rci@servtec-international.com. Offre complète : https://lnkd.in/dGyyQHkb.', NULL, 'https://lnkd.in/dGyyQHkb', 
    '', 'recrutement.rci@servtec-international.com', true, NULL, ARRAY['Claim management', 'BTP', 'Droit', 'Contentieux'], 
    false, NULL, '{"title": "Claim Manager", "company_name": "SERVTEC C\u00f4te d\u2019Ivoire", "summary": "Piloter gestion des r\u00e9clamations, sinistres, analyser risques. Profil : Bac+5 en G\u00e9nie Civil, Droit, Management de Projets ; 5-10 ans exp\u00e9rience en gestion de claims BTP ; connaissance droit OHADA, contrats FIDIC, NEC. Envoyer CV \u00e0 recrutement.rci@servtec-international.com. Offre compl\u00e8te : https://lnkd.in/dGyyQHkb.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/dGyyQHkb", "email": "recrutement.rci@servtec-international.com", "deadline": null, "niveau": "BAC+5", "lieu": null, "tags": ["Claim management", "BTP", "Droit", "Contentieux"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'PROJECT MANAGER - M/F', 'AGILOYA AFRIQUE (pour client)', 'https://lnkd.in/e4UwdzhD', '18/05/2026', NULL, 
    '5+ years project/event management experience, leadership, logistics, English. Location: Johannesburg. Postuler via plateforme : https://lnkd.in/e4UwdzhD. Deadline: May 18, 2026.', NULL, 'https://lnkd.in/e4UwdzhD', 
    '', NULL, true, 'Johannesburg', ARRAY['Project management', 'Événementiel', 'International'], 
    false, NULL, '{"title": "PROJECT MANAGER - M/F", "company_name": "AGILOYA AFRIQUE (pour client)", "summary": "5+ years project/event management experience, leadership, logistics, English. Location: Johannesburg. Postuler via plateforme : https://lnkd.in/e4UwdzhD. Deadline: May 18, 2026.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/e4UwdzhD", "email": null, "deadline": "18/05/2026", "niveau": null, "lieu": "Johannesburg", "tags": ["Project management", "\u00c9v\u00e9nementiel", "International"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Assistant.e Marketing & Communication Digital', 'DMARK CONSULTING', 'extraction6_id_34', NULL, NULL, 
    'Expérience significative d’au moins 1 an. Envoyer CV et lettre de motivation à contact@dmarkconsulting.com.', NULL, NULL, 
    '', 'contact@dmarkconsulting.com', true, NULL, ARRAY['Marketing digital', 'Communication', 'Assistant'], 
    true, 'OUI', '{"title": "Assistant.e Marketing & Communication Digital", "company_name": "DMARK CONSULTING", "summary": "Exp\u00e9rience significative d\u2019au moins 1 an. Envoyer CV et lettre de motivation \u00e0 contact@dmarkconsulting.com.", "contact": null, "lettre_motivation": "OUI", "objet": null, "urls": null, "email": "contact@dmarkconsulting.com", "deadline": null, "niveau": null, "lieu": null, "tags": ["Marketing digital", "Communication", "Assistant"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Chargé.e de Communication Digitale', 'DMARK CONSULTING', 'extraction6_id_35', NULL, NULL, 
    'Expérience significative d’au moins 2 ans. Envoyer CV et lettre de motivation à contact@dmarkconsulting.com.', NULL, NULL, 
    '', 'contact@dmarkconsulting.com', true, NULL, ARRAY['Communication digitale', 'Marketing'], 
    true, 'OUI', '{"title": "Charg\u00e9.e de Communication Digitale", "company_name": "DMARK CONSULTING", "summary": "Exp\u00e9rience significative d\u2019au moins 2 ans. Envoyer CV et lettre de motivation \u00e0 contact@dmarkconsulting.com.", "contact": null, "lettre_motivation": "OUI", "objet": null, "urls": null, "email": "contact@dmarkconsulting.com", "deadline": null, "niveau": null, "lieu": null, "tags": ["Communication digitale", "Marketing"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Commercial, Commis Pâtissier, Econome', 'Hotel & Luxury Housing (HLH)', 'extraction6_id_36', '23/03/2026', NULL, 
    'Postes : Commercial, Commis Pâtissier, Econome. Profil : professionnels passionnés par hôtellerie luxe, sens du service, relationnel. Envoyer CV à travis.alles@sihmci.com, objet : "Candidature - {Intitulé du poste}". Deadline : 23 mars 2026.', 'Candidature - {Intitulé du poste}', NULL, 
    '', 'travis.alles@sihmci.com', true, NULL, ARRAY['Hôtellerie', 'Pâtisserie', 'Économat', 'Commerce'], 
    false, NULL, '{"title": "Commercial, Commis P\u00e2tissier, Econome", "company_name": "Hotel & Luxury Housing (HLH)", "summary": "Postes : Commercial, Commis P\u00e2tissier, Econome. Profil : professionnels passionn\u00e9s par h\u00f4tellerie luxe, sens du service, relationnel. Envoyer CV \u00e0 travis.alles@sihmci.com, objet : \"Candidature - {Intitul\u00e9 du poste}\". Deadline : 23 mars 2026.", "contact": null, "lettre_motivation": null, "objet": "Candidature - {Intitul\u00e9 du poste}", "urls": null, "email": "travis.alles@sihmci.com", "deadline": "23/03/2026", "niveau": null, "lieu": null, "tags": ["H\u00f4tellerie", "P\u00e2tisserie", "\u00c9conomat", "Commerce"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'GESTIONNAIRE PAIE H/F', 'TRUST AFRICA (secteur minier)', 'https://bit.ly/40VMvqd', NULL, NULL, 
    'Poste à Fria. Postuler via https://bit.ly/40VMvqd ou envoyer CV à job@trustafrica-rh.com en indiquant titre et référence du poste.', NULL, 'https://bit.ly/40VMvqd', 
    '', 'job@trustafrica-rh.com', true, 'Fria', ARRAY['Paie', 'RH', 'Mines'], 
    false, NULL, '{"title": "GESTIONNAIRE PAIE H/F", "company_name": "TRUST AFRICA (secteur minier)", "summary": "Poste \u00e0 Fria. Postuler via https://bit.ly/40VMvqd ou envoyer CV \u00e0 job@trustafrica-rh.com en indiquant titre et r\u00e9f\u00e9rence du poste.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://bit.ly/40VMvqd", "email": "job@trustafrica-rh.com", "deadline": null, "niveau": null, "lieu": "Fria", "tags": ["Paie", "RH", "Mines"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Auditeur(trice) Confirmé(e)', 'UCB (Groupe KADJI)', 'extraction6_id_38', '21/03/2026', 'BAC+5', 
    'Profil : BAC+5 en Audit, Finance, Comptabilité, Gestion des Risques ; 3-5 ans expérience ; maîtrise COSO, IIA, SYSCOHADA, Excel avancé, SAP, anglais. Poste à Douala. Envoyer CV PDF à recrutement@sa-ucb.com, objet AUDINT_032025, deadline 21 mars 2026 à 17H00.', 'AUDINT_032025', NULL, 
    '', 'recrutement@sa-ucb.com', true, 'Douala', ARRAY['Audit', 'Finance', 'Comptabilité', 'Risques'], 
    false, NULL, '{"title": "Auditeur(trice) Confirm\u00e9(e)", "company_name": "UCB (Groupe KADJI)", "summary": "Profil : BAC+5 en Audit, Finance, Comptabilit\u00e9, Gestion des Risques ; 3-5 ans exp\u00e9rience ; ma\u00eetrise COSO, IIA, SYSCOHADA, Excel avanc\u00e9, SAP, anglais. Poste \u00e0 Douala. Envoyer CV PDF \u00e0 recrutement@sa-ucb.com, objet AUDINT_032025, deadline 21 mars 2026 \u00e0 17H00.", "contact": null, "lettre_motivation": null, "objet": "AUDINT_032025", "urls": null, "email": "recrutement@sa-ucb.com", "deadline": "21/03/2026", "niveau": "BAC+5", "lieu": "Douala", "tags": ["Audit", "Finance", "Comptabilit\u00e9", "Risques"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Responsable Logistique & Dépôt (H/F)', 'AT225', 'https://lnkd.in/eQieTYJr', NULL, 'BAC+3, BAC+4, BAC+5', 
    'Secteur BTP. Profil : Bac+3/5 en logistique, supply chain, transport ; 5 ans expérience ; outils Excel, ERP, CRM. Postulez via https://lnkd.in/eQieTYJr.', NULL, 'https://lnkd.in/eQieTYJr', 
    '', NULL, true, NULL, ARRAY['Logistique', 'Supply chain', 'BTP'], 
    false, NULL, '{"title": "Responsable Logistique & D\u00e9p\u00f4t (H/F)", "company_name": "AT225", "summary": "Secteur BTP. Profil : Bac+3/5 en logistique, supply chain, transport ; 5 ans exp\u00e9rience ; outils Excel, ERP, CRM. Postulez via https://lnkd.in/eQieTYJr.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/eQieTYJr", "email": null, "deadline": null, "niveau": "BAC+3, BAC+4, BAC+5", "lieu": null, "tags": ["Logistique", "Supply chain", "BTP"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'CHEF D’AGENCE MICROFINANCE (H/F)', 'CELPAID FINANCE SA', 'extraction6_id_40', NULL, 'BAC+3', 
    'Postes à Abidjan et intérieur. Missions : gestion opérationnelle, encadrement, développement portefeuille, recouvrement. Profil : Bac+3 gestion, finance, économie ; 3 ans expérience similaire ; management, développement commercial. Envoyer CV+LM à recrutement@celpaid.com, objet : "Candidature Chef d’Agence – Prétention salariale".', 'Candidature Chef d’Agence – Prétention salariale', NULL, 
    '', 'recrutement@celpaid.com', true, 'Abidjan et intérieur', ARRAY['Microfinance', 'Chef d''agence', 'Gestion'], 
    true, 'OUI', '{"title": "CHEF D\u2019AGENCE MICROFINANCE (H/F)", "company_name": "CELPAID FINANCE SA", "summary": "Postes \u00e0 Abidjan et int\u00e9rieur. Missions : gestion op\u00e9rationnelle, encadrement, d\u00e9veloppement portefeuille, recouvrement. Profil : Bac+3 gestion, finance, \u00e9conomie ; 3 ans exp\u00e9rience similaire ; management, d\u00e9veloppement commercial. Envoyer CV+LM \u00e0 recrutement@celpaid.com, objet : \"Candidature Chef d\u2019Agence \u2013 Pr\u00e9tention salariale\".", "contact": null, "lettre_motivation": "OUI", "objet": "Candidature Chef d\u2019Agence \u2013 Pr\u00e9tention salariale", "urls": null, "email": "recrutement@celpaid.com", "deadline": null, "niveau": "BAC+3", "lieu": "Abidjan et int\u00e9rieur", "tags": ["Microfinance", "Chef d''agence", "Gestion"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'RESPONSABLE JURIDIQUE (H/F)', 'Le CIFIP (secteur financier)', 'extraction6_id_41', NULL, 'BAC+4, BAC+5', 
    'Missions : rédiger/valider contrats, assistance juridique, contentieux, veille, secrétariat juridique. Profil : Bac+4/5 en droit ; 5 ans expérience similaire dans secteur financier ou cabinet. Envoyer CV & prétentions salariales à recrutement@cifip-ci.com.', NULL, NULL, 
    '', 'recrutement@cifip-ci.com', true, NULL, ARRAY['Juridique', 'Droit', 'Contentieux', 'Finance'], 
    false, NULL, '{"title": "RESPONSABLE JURIDIQUE (H/F)", "company_name": "Le CIFIP (secteur financier)", "summary": "Missions : r\u00e9diger/valider contrats, assistance juridique, contentieux, veille, secr\u00e9tariat juridique. Profil : Bac+4/5 en droit ; 5 ans exp\u00e9rience similaire dans secteur financier ou cabinet. Envoyer CV & pr\u00e9tentions salariales \u00e0 recrutement@cifip-ci.com.", "contact": null, "lettre_motivation": null, "objet": null, "urls": null, "email": "recrutement@cifip-ci.com", "deadline": null, "niveau": "BAC+4, BAC+5", "lieu": null, "tags": ["Juridique", "Droit", "Contentieux", "Finance"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Manager Projets IT', 'VEONE', 'https://lnkd.in/dzKG8Zp8', NULL, NULL, 
    'Gestion opérationnelle de projets complexes, coordination équipes, reporting, Scrum Master. Postulez via https://lnkd.in/dzKG8Zp8.', NULL, 'https://lnkd.in/dzKG8Zp8', 
    '', NULL, true, NULL, ARRAY['Informatique', 'Gestion de projet', 'IT', 'Agile'], 
    false, NULL, '{"title": "Manager Projets IT", "company_name": "VEONE", "summary": "Gestion op\u00e9rationnelle de projets complexes, coordination \u00e9quipes, reporting, Scrum Master. Postulez via https://lnkd.in/dzKG8Zp8.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/dzKG8Zp8", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["Informatique", "Gestion de projet", "IT", "Agile"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Responsable Administratif et Financier (F/H)', 'RMO_TOGO', 'https://lnkd.in/gnVupTiW', NULL, NULL, 
    'Postuler via le lien : https://lnkd.in/gnVupTiW.', NULL, 'https://lnkd.in/gnVupTiW', 
    '', NULL, true, NULL, ARRAY['RAF', 'Finance', 'Administration'], 
    false, NULL, '{"title": "Responsable Administratif et Financier (F/H)", "company_name": "RMO_TOGO", "summary": "Postuler via le lien : https://lnkd.in/gnVupTiW.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/gnVupTiW", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["RAF", "Finance", "Administration"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Développeur Sage X & Power BI H/F', 'CFAO Consumer Côte d''Ivoire', 'https://lnkd.in/e6V_An9Y', NULL, NULL, 
    'Découvrez les missions via le lien : https://lnkd.in/e6V_An9Y.', NULL, 'https://lnkd.in/e6V_An9Y', 
    '', NULL, true, NULL, ARRAY['Informatique', 'Développement', 'Sage X', 'Power BI'], 
    false, NULL, '{"title": "D\u00e9veloppeur Sage X & Power BI H/F", "company_name": "CFAO Consumer C\u00f4te d''Ivoire", "summary": "D\u00e9couvrez les missions via le lien : https://lnkd.in/e6V_An9Y.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/e6V_An9Y", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["Informatique", "D\u00e9veloppement", "Sage X", "Power BI"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'CONTROLEUR DE GESTION - H/F', 'AGILOYA AFRIQUE (pour client assurance vie)', 'https://lnkd.in/eFbxW66m', '17/04/2026', 'BAC+4, BAC+5', 
    'Bac+4/5 en Finance, Gestion, Audit ; 5 ans expérience similaire ; maîtrise techniques d''audit et contrôle de gestion ; connaissances assurances. Poste basé à Abidjan. Postuler via plateforme : https://lnkd.in/eFbxW66m. Deadline : 17/04/2026.', NULL, 'https://lnkd.in/eFbxW66m', 
    '', NULL, true, 'Abidjan', ARRAY['Contrôle de gestion', 'Finance', 'Assurance'], 
    false, NULL, '{"title": "CONTROLEUR DE GESTION - H/F", "company_name": "AGILOYA AFRIQUE (pour client assurance vie)", "summary": "Bac+4/5 en Finance, Gestion, Audit ; 5 ans exp\u00e9rience similaire ; ma\u00eetrise techniques d''audit et contr\u00f4le de gestion ; connaissances assurances. Poste bas\u00e9 \u00e0 Abidjan. Postuler via plateforme : https://lnkd.in/eFbxW66m. Deadline : 17/04/2026.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/eFbxW66m", "email": null, "deadline": "17/04/2026", "niveau": "BAC+4, BAC+5", "lieu": "Abidjan", "tags": ["Contr\u00f4le de gestion", "Finance", "Assurance"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Gestionnaire de comptes PME/PMI', 'Ecobank Côte d''Ivoire', 'https://lnkd.in/ehQ_HFBf', NULL, NULL, 
    'Développer, gérer et fidéliser portefeuille PME/PMI, développement commercial, acquisition clients, vente solutions bancaires. Profil : expérience confirmée en gestion portefeuille PME/PMI, compétences commerciales, analyse financière, gestion risques. Postulez via https://lnkd.in/ehQ_HFBf.', NULL, 'https://lnkd.in/ehQ_HFBf', 
    '', NULL, true, NULL, ARRAY['Banque', 'PME', 'Gestion de portefeuille'], 
    false, NULL, '{"title": "Gestionnaire de comptes PME/PMI", "company_name": "Ecobank C\u00f4te d''Ivoire", "summary": "D\u00e9velopper, g\u00e9rer et fid\u00e9liser portefeuille PME/PMI, d\u00e9veloppement commercial, acquisition clients, vente solutions bancaires. Profil : exp\u00e9rience confirm\u00e9e en gestion portefeuille PME/PMI, comp\u00e9tences commerciales, analyse financi\u00e8re, gestion risques. Postulez via https://lnkd.in/ehQ_HFBf.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/ehQ_HFBf", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["Banque", "PME", "Gestion de portefeuille"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Superviseur Ligne de Production Canettes (H/F)', 'AT225', 'https://lnkd.in/ey6jX5c9', NULL, 'BAC+2, BAC+3', 
    'Secteur agro-alimentaire. Profil : BTS/DUT ou Licence Pro en Industrie Alimentaire, Génie Industriel ; 3-5 ans expérience en ligne de conditionnement. Postulez via https://lnkd.in/ey6jX5c9.', NULL, 'https://lnkd.in/ey6jX5c9', 
    '', NULL, true, NULL, ARRAY['Production', 'Agro-alimentaire', 'Conditionnement', 'Supervision'], 
    false, NULL, '{"title": "Superviseur Ligne de Production Canettes (H/F)", "company_name": "AT225", "summary": "Secteur agro-alimentaire. Profil : BTS/DUT ou Licence Pro en Industrie Alimentaire, G\u00e9nie Industriel ; 3-5 ans exp\u00e9rience en ligne de conditionnement. Postulez via https://lnkd.in/ey6jX5c9.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/ey6jX5c9", "email": null, "deadline": null, "niveau": "BAC+2, BAC+3", "lieu": null, "tags": ["Production", "Agro-alimentaire", "Conditionnement", "Supervision"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Gestionnaire Commercial Transit (3 postes)', 'Distrimat Inter Courrier Express', 'extraction6_id_48', '20/03/2026', NULL, 
    'Envoyer candidature à recrutement@distrimatinter.com. Date limite : 20 mars 2026.', NULL, NULL, 
    '', 'recrutement@distrimatinter.com', true, NULL, ARRAY['Transit', 'Commerce', 'Logistique'], 
    false, NULL, '{"title": "Gestionnaire Commercial Transit (3 postes)", "company_name": "Distrimat Inter Courrier Express", "summary": "Envoyer candidature \u00e0 recrutement@distrimatinter.com. Date limite : 20 mars 2026.", "contact": null, "lettre_motivation": null, "objet": null, "urls": null, "email": "recrutement@distrimatinter.com", "deadline": "20/03/2026", "niveau": null, "lieu": null, "tags": ["Transit", "Commerce", "Logistique"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Gestionnaire de Prêt (F/H)', 'RMO_TOGO', 'https://lnkd.in/gdfPc8QV', NULL, NULL, 
    'Postuler via le lien : https://lnkd.in/gdfPc8QV.', NULL, 'https://lnkd.in/gdfPc8QV', 
    '', NULL, true, NULL, ARRAY['Prêt', 'Finance', 'Gestion'], 
    false, NULL, '{"title": "Gestionnaire de Pr\u00eat (F/H)", "company_name": "RMO_TOGO", "summary": "Postuler via le lien : https://lnkd.in/gdfPc8QV.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/gdfPc8QV", "email": null, "deadline": null, "niveau": null, "lieu": null, "tags": ["Pr\u00eat", "Finance", "Gestion"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Maçon, Coffreur, Électricien bâtiment, Manœuvre BTP, Chef d’équipe chantier', 'H2C Africa', 'extraction6_id_50', NULL, NULL, 
    'Postes à Bingerville, Grand-Bassam & Dabou. Envoyer CV et prétentions salariales à recrutement@h2c-africa.com avec objet du poste, ou via WhatsApp, ou dépôt physique.', 'intitulé du poste', NULL, 
    '2250556460336', 'recrutement@h2c-africa.com', true, 'Bingerville, Grand-Bassam, Dabou', ARRAY['BTP', 'Construction', 'Maçon', 'Coffreur', 'Électricien', 'Manœuvre'], 
    false, NULL, '{"title": "Ma\u00e7on, Coffreur, \u00c9lectricien b\u00e2timent, Man\u0153uvre BTP, Chef d\u2019\u00e9quipe chantier", "company_name": "H2C Africa", "summary": "Postes \u00e0 Bingerville, Grand-Bassam & Dabou. Envoyer CV et pr\u00e9tentions salariales \u00e0 recrutement@h2c-africa.com avec objet du poste, ou via WhatsApp, ou d\u00e9p\u00f4t physique.", "contact": "+225 05 56 46 03 36 (WhatsApp)", "lettre_motivation": null, "objet": "intitul\u00e9 du poste", "urls": null, "email": "recrutement@h2c-africa.com", "deadline": null, "niveau": null, "lieu": "Bingerville, Grand-Bassam, Dabou", "tags": ["BTP", "Construction", "Ma\u00e7on", "Coffreur", "\u00c9lectricien", "Man\u0153uvre"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Chauffeurs (permis B)', 'Total Emploi RH', 'extraction6_id_51', '30/03/2026', NULL, 
    'Expérience 2 ans. Date limite : 30/03/2026. Postuler via info@total-emploirh.com.', NULL, NULL, 
    '237233430041673722341', 'info@total-emploirh.com', true, NULL, ARRAY['Chauffeur', 'Transport'], 
    false, NULL, '{"title": "Chauffeurs (permis B)", "company_name": "Total Emploi RH", "summary": "Exp\u00e9rience 2 ans. Date limite : 30/03/2026. Postuler via info@total-emploirh.com.", "contact": "+237 233 43 00 41 / 673 72 23 41", "lettre_motivation": null, "objet": null, "urls": null, "email": "info@total-emploirh.com", "deadline": "30/03/2026", "niveau": null, "lieu": null, "tags": ["Chauffeur", "Transport"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;

INSERT INTO public.jobs (
    job_title, company_name, source_url, deadline, required_level, 
    description, application_instructions, application_link, 
    whatsapp_number, contact_email, is_ai_verified, location, tags, 
    requires_cover_letter, cover_letter_instructions, raw_data
) VALUES (
    'Ingénieur mécanique principal', 'ICM HOLDING', 'https://lnkd.in/er4P3HE4', '25/03/2026', NULL, 
    'CDD 3-6 mois, prise de poste immédiate. Deadline : 25 mars 2026. Détails et formulaire : https://lnkd.in/er4P3HE4.', NULL, 'https://lnkd.in/er4P3HE4', 
    '', NULL, true, 'Abidjan', ARRAY['Ingénierie', 'Mécanique', 'Pétrole et gaz'], 
    false, NULL, '{"title": "Ing\u00e9nieur m\u00e9canique principal", "company_name": "ICM HOLDING", "summary": "CDD 3-6 mois, prise de poste imm\u00e9diate. Deadline : 25 mars 2026. D\u00e9tails et formulaire : https://lnkd.in/er4P3HE4.", "contact": null, "lettre_motivation": null, "objet": null, "urls": "https://lnkd.in/er4P3HE4", "email": null, "deadline": "25/03/2026", "niveau": null, "lieu": "Abidjan", "tags": ["Ing\u00e9nierie", "M\u00e9canique", "P\u00e9trole et gaz"], "salary_range": null}'
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
    raw_data = EXCLUDED.raw_data;