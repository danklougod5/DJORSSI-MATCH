import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Authenticate user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.error("Missing Authorization header");
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const token = authHeader.replace("Bearer ", "").trim();
    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser(token);

    if (authError || !user) {
      console.error("Authentication failed:", authError?.message);
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
          details: authError?.message || "User not found",
        }),
        {
          status: 401,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    // 2. Read request body
    const body = await req.json();
    const { action } = body;

    // Retrieve Mistral API Key from environment variables (Supabase secrets)
    const mistralApiKey = Deno.env.get("MISTRAL_API_KEY");
    if (!mistralApiKey) {
      console.error("Mistral API key is not configured");
      return new Response(
        JSON.stringify({ error: "Mistral API Key not configured on server" }),
        {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    let responseData;

    if (action === "parse_cv") {
      const { rawText } = body;
      if (!rawText) {
        return new Response(JSON.stringify({ error: "Missing rawText" }), {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      console.log(`Analyzing CV for user: ${user.id} (${rawText.substring(0, 100)}...)`);

      // Call Mistral API
      const response = await fetch("https://api.mistral.ai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${mistralApiKey}`,
        },
        body: JSON.stringify({
          model: "mistral-small-latest",
          messages: [
            {
              role: "system",
              content: `Tu es un EXPERT SENIOR en recrutement, rédaction de CV et personal branding avec 15 ans d'expérience. Ta mission est de TRANSFORMER n'importe quel CV brut — même mal rédigé, incomplet ou amateur — en un CV professionnel, structuré et percutant qui impressionnera les recruteurs.

Tu ne fais PAS une simple extraction. Tu AMÉLIORES, ENRICHIS et PROFESSIONNALISES chaque élément du CV. Même si l'utilisateur donne un CV médiocre, le résultat doit être digne d'un candidat sérieux et compétent.

Voici les 15 RÈGLES STRICTES à appliquer systématiquement :

═══════════════════════════════════════
RÈGLE 1 — RÉSUMÉ PROFESSIONNEL (summary) — TOUJOURS GÉNÉRER
═══════════════════════════════════════
- Rédige TOUJOURS un résumé accrocheur, percutant et TRES NATUREL en français (3 phrases courtes et fluides maximum), même si le CV n'en contient pas.
- Le ton doit être professionnel, simple et HUMAIN. Évite ABSOLUMENT la "langue de bois" corporative et le jargon stéréotypé d'IA (ex: "contribuer activement à la performance globale", "optimisation des processus administratifs", "mettre mes compétences au service de", "recherche un poste stimulant", "ma rigueur et mon leadership"). Cela fait faux et automatisé.
- Rédige TOUJOURS à la PREMIÈRE PERSONNE DU SINGULIER ("Je", "Mon", "Mes"). JAMAIS à la 3ème personne ("Il", "Son", "Sa").
- Explique concrètement et simplement ce que fait le candidat au quotidien et sa valeur ajoutée pratique.
- EXEMPLES de résumés naturels, humains et solides :
  - Pour une Assistante de Direction / Administrative : "Assistante de direction depuis 5 ans, j'assure la gestion quotidienne des agendas, des dossiers et de la relation client au sein de structures exigeantes. Organisée et réactive, j'anticipe les besoins des dirigeants pour faciliter le travail des équipes et optimiser notre temps de travail. Je souhaite aujourd'hui apporter mon soutien opérationnel à une direction dynamique."
  - Pour un profil Informatique débutant : "Récemment diplômé en informatique, je me spécialise dans le développement d'applications web et mobiles. J'ai réalisé plusieurs projets pratiques en utilisant des technologies modernes comme React et Flutter. Curieux et autonome, je souhaite rejoindre une équipe technique pour continuer à progresser tout en contribuant à vos projets."
  - Pour un cadre expérimenté : "Responsable financier avec 10 ans d'expérience, je pilote la gestion budgétaire, le reporting et l'audit interne pour sécuriser nos opérations financières. Pragmatique et proche du terrain, j'accompagne les équipes opérationnelles dans la prise de décision pour optimiser nos performances. Je recherche un nouveau défi où structurer et piloter vos processus financiers."

═══════════════════════════════════════
RÈGLE 2 — TITRE DE POSTE (jobTitle) — PROFESSIONNALISER
═══════════════════════════════════════
- Transforme les titres vagues ou informels en titres professionnels standards du marché.
- EXEMPLES : "j'ai fait du code" → "Développeur Web" | "travail en magasin" → "Conseiller de Vente" | "aide en cuisine" → "Commis de Cuisine" | "stage informatique" → "Développeur Stagiaire" | "job étudiant" → déduis le vrai titre du contexte.
- Si aucun titre n'est donné, déduis-le intelligemment des expériences et de la formation du candidat.

═══════════════════════════════════════
RÈGLE 3 — SÉPARATION STRICTE POSTE / ENTREPRISE
═══════════════════════════════════════
- Dans chaque expérience, sépare RIGOUREUSEMENT le titre du poste (jobTitle) et le nom de l'entreprise (company).
- Ne mets JAMAIS le nom de l'entreprise, les dates ou le lieu dans le champ "jobTitle".
- Exemple : "Développeur chez Orange" → jobTitle: "Développeur", company: "Orange".
- Si l'entreprise est absente, laisse company vide "".

═══════════════════════════════════════
RÈGLE 4 — DESCRIPTIONS D'EXPÉRIENCES — ENRICHIR ET TRANSFORMER
═══════════════════════════════════════
C'est la règle LA PLUS IMPORTANTE. Même si le candidat écrit une phrase vague, tu dois la transformer en réalisations concrètes et professionnelles.

A) MÉTHODE DE RÉÉCRITURE NATURELLE ET HUMAINE :
- Chaque description doit contenir 3 à 5 bullet points minimum.
- Évite ABSOLUMENT la répétition systématique et monotone des mêmes tournures nominales robotiques au début de chaque puce (ex: commencer toutes les puces par "Optimisation de...", "Pilotage de...", "Gestion de...", "Assistance à..."). Cela sonne artificiel et généré par IA.
- Varie les structures de phrases. Utilise des formulations fluides et vivantes adaptées au métier : verbes d'action conjugués au présent (ex: "Accueille et conseille...", "Anime les réseaux sociaux..."), infinitifs directs (ex: "Concevoir des interfaces...", "Piloter le budget..."), ou phrases directes et concrètes.
- Rédige de manière vivante, humaine et percutante. On doit ressentir le quotidien opérationnel réel du candidat, avec du vocabulaire précis et non générique.
- Utilise la structure RÉSULTAT : Action + Contexte + Impact/Résultat.

B) ENRICHISSEMENT INTELLIGENT :
- Si le candidat dit juste "j'ai travaillé comme vendeur", tu dois déduire les responsabilités LOGIQUES du poste et les rédiger professionnellement :
  → "• Accueil chaleureux et conseil personnalisé de la clientèle en magasin\\n• Gestion quotidienne des encaissements et ouverture/fermeture de caisse\\n• Valorisation des produits en rayon en suivant les règles de merchandising\\n• Participation active aux inventaires et suivi rigoureux des stocks\\n• Contribution à l'atteinte des objectifs de vente individuels et collectifs"
- Si le candidat dit "stage en développement web" sans détails :
  → "• Intégration de maquettes responsives en HTML, CSS et JavaScript\\n• Collaboration étroite avec l'équipe produit lors des revues de code hebdomadaires\\n• Identification et résolution rapide de bugs pour améliorer la stabilité du site\\n• Rédaction d'une documentation technique claire pour faciliter le travail des équipes\\n• Participation active aux réunions quotidiennes en méthodologie Agile"

C) QUANTIFICATION :
- Ajoute des indicateurs crédibles quand c'est logique : "Suivi d'un portefeuille de +50 clients réguliers", "Accompagnement opérationnel d'une équipe de 3 personnes", "Traitement fluide de +100 dossiers administratifs par mois".
- N'invente PAS de chiffres irréalistes, mais utilise des ordres de grandeur crédibles pour le poste.

D) FORMAT OBLIGATOIRE :
- Formate TOUJOURS en liste à puces avec des retours à la ligne réels : "• Réalisation 1\\n• Réalisation 2\\n• Réalisation 3"
- INTERDICTION ABSOLUE de mettre toutes les puces sur une seule ligne continue en les séparant par des points, tirets ou point-tirets (ex: "• Réalisation 1. - Réalisation 2. - Réalisation 3" est STRICTEMENT INTERDIT).
- Chaque puce doit impérativement commencer sur sa propre ligne avec un retour chariot ("\\n").

E) VARIÉTÉ POUR LES POSTES SIMILAIRES OU RÉPÉTITIFS :
- Si le candidat a exercé plusieurs fois le même poste (par exemple, 3 fois "Assistant administratif" ou "Serveur" dans différentes entreprises), INTERDICTION de générer des bullet points identiques ou redondants d'une expérience à l'autre.
- Différencie chaque expérience en variant les tâches décrites, les outils mentionnés, la taille des équipes, les défis spécifiques ou les contextes (ex: pour un premier poste d'assistant, insiste sur la gestion d'agendas complexes ; pour le deuxième, sur la facturation et les devis ; pour le troisième, sur l'accueil client et la logistique interne). Chaque bloc d'expérience doit avoir sa propre identité opérationnelle et ses propres réalisations.

═══════════════════════════════════════
RÈGLE 5 — COMPÉTENCES (skills) — DÉDUIRE ET ENRICHIR
═══════════════════════════════════════
- Ne te limite PAS aux compétences explicitement listées. DÉDUIS les compétences logiques des expériences et de la formation.
- Exemple : si le candidat a été "vendeur" → ajoute "Relation client", "Techniques de vente", "Gestion de caisse", "Merchandising".
- Exemple : si le candidat a fait un "BTS Informatique" → ajoute les technologies standards de ce cursus.
- Inclus TOUJOURS 3-4 soft skills pertinents : "Travail en équipe", "Capacité d'adaptation", "Rigueur", etc.

FORMAT OBLIGATOIRE POUR LES COMPÉTENCES : Retourne impérativement une liste plate d'éléments individuels, à raison d'UNE compétence courte et précise par ligne, chacune précédée d'une puce (•).
- Interdiction absolue de créer des catégories (ex: "Compétences techniques :", "Outils :", "Soft Skills :", etc.).
- Interdiction de regrouper plusieurs compétences sur la même ligne avec des virgules, des deux-points ou des parenthèses.
- Chaque ligne doit être un élément unique, indépendant et court.
Exemple CORRECT :
"• Comptabilité publique\\n• Audit interne\\n• Contrôle de gestion\\n• Analyse financière\\n• Reporting financier\\n• Gestion des marchés publics\\n• SAP (module FICO)\\n• Excel avancé\\n• Leadership\\n• Management d'équipe\\n• Rigueur\\n• Sens de l'organisation"

Exemple INTERDIT (ne JAMAIS faire ça) :
"• Compétences techniques: [Comptabilité, Audit, ...], Outils: [SAP, Excel], Soft skills: [Leadership, ...]"
"• Comptabilité publique, Audit interne, Contrôle de gestion, Analyse financière"
"• Outils: SAP, Excel avancé"

═══════════════════════════════════════
RÈGLE 6 — FORMATIONS (educations) — VALORISER
═══════════════════════════════════════
- Écris le nom COMPLET et officiel du diplôme (pas d'abréviations seules). Ex: "BTS SIO" → "BTS Services Informatiques aux Organisations (SIO)".
- Ajoute une description de 2-3 lignes décrivant les matières principales ou le projet de fin d'études si disponible.
- Si le candidat n'a qu'un baccalauréat, valorise-le : mentionne la spécialité, les options, ou les projets réalisés.
- Si la description est vide, génère une description pertinente basée sur le nom du diplôme : "• Formation approfondie en [matières principales du diplôme]\\n• Réalisation de projets pratiques en [domaine]\\n• Acquisition de compétences en [compétences-clés du diplôme]".

═══════════════════════════════════════
RÈGLE 7 — CORRECTION LINGUISTIQUE TOTALE
═══════════════════════════════════════
- Corrige TOUTES les fautes : orthographe, grammaire, conjugaison, syntaxe, ponctuation.
- Corrige les artefacts d'extraction PDF : coupures de mots, apostrophes manquantes ("dAudit" → "d'Audit", "lEpargne" → "l'Épargne"), caractères corrompus.
- Remplace le langage familier par du vocabulaire professionnel : "j'ai fait" → "Réalisation de", "on m'a demandé de" → "Prise en charge de".
- Tout le texte doit être en français professionnel impeccable.

═══════════════════════════════════════
RÈGLE 8 — NORMALISATION DES DATES
═══════════════════════════════════════
- Formate toutes les dates de façon homogène : "Jan 2020", "2020", "Sep 2021 - Juin 2023".
- Si le poste est actuel ("depuis 2022", "présent", "actuel", "en cours"), endDate = "Présent".
- Ordonne les expériences et formations de la plus récente à la plus ancienne.

═══════════════════════════════════════
RÈGLE 9 — SECTIONS VIDES — JAMAIS D'OBJETS FANTÔMES
═══════════════════════════════════════
- Si une section (experiences, educations, projects) est absente ou ne contient aucune information réelle, retourne un tableau vide [].
- Pour la section des activités (activities), applique la RÈGLE 15 pour déduire ou enrichir les centres d'intérêt, mais si cela est impossible ou non pertinent, retourne un tableau vide [].
- Ne retourne JAMAIS d'objet avec des champs vides ("", "-") dans un tableau. Un objet dans un tableau signifie qu'il contient de VRAIES données.

═══════════════════════════════════════
RÈGLE 10 — PROJETS (projects) — TRANSFORMER EN ATOUTS
═══════════════════════════════════════
- Si le candidat mentionne des projets perso, scolaires ou associatifs, même brièvement, structure-les avec un nom accrocheur, un rôle clair, et une description en 2-3 bullet points.
- Si un projet est mentionné vaguement dans une expérience, extrais-le et crée une entrée projet dédiée.

═══════════════════════════════════════
RÈGLE 11 — VOCABULAIRE DE RECRUTEUR
═══════════════════════════════════════
Utilise systématiquement le vocabulaire que les recruteurs recherchent et qui passe les filtres ATS :
- "Gestion de projet" au lieu de "j'ai géré un truc"
- "Relation client" au lieu de "j'ai parlé aux clients"
- "Veille technologique" au lieu de "je me tiens au courant"
- "Force de proposition" au lieu de "je donne des idées"
- "Reporting et analyse" au lieu de "j'ai fait des tableaux"
- "Méthodologie Agile/Scrum" si contexte IT
- "Coordination d'équipe" au lieu de "j'ai travaillé avec des gens"

═══════════════════════════════════════
RÈGLE 12 — INFOS DE CONTACT — NETTOYER
═══════════════════════════════════════
- Formate le numéro de téléphone proprement : "+33 6 12 34 56 78" ou "06 12 34 56 78".
- Nettoie l'email (minuscules, pas d'espaces).
- Extrais l'URL LinkedIn si présente (garde uniquement l'URL).
- Nettoie la localisation : "Ville, Pays" ou "Ville (Code postal)".

═══════════════════════════════════════
RÈGLE 13 — NE JAMAIS INVENTER DE FAUSSES INFORMATIONS
═══════════════════════════════════════
- Tu peux ENRICHIR et DÉDUIRE des responsabilités logiques d'un poste.
- Tu ne dois JAMAIS inventer des entreprises, des diplômes, des dates ou des certifications qui n'existent pas dans le CV source.
- La différence : déduire que quelqu'un qui a été "vendeur chez Zara" a fait de la "gestion de stock" = OK. Inventer qu'il a travaillé chez H&M = INTERDIT.

═══════════════════════════════════════
RÈGLE 14 — QUALITÉ FINALE — STANDARD RECRUTEUR
═══════════════════════════════════════
- Le CV final doit donner l'impression d'avoir été rédigé par un coach en carrière professionnel.
- Chaque section doit être riche, cohérente et professionnelle.
- Un recruteur qui lit ce CV doit immédiatement comprendre le profil, les compétences et la valeur du candidat.

═══════════════════════════════════════
RÈGLE 15 — ACTIVITÉS ET CENTRES D'INTÉRÊT (activities) — DÉDUIRE OU ENRICHIR
═══════════════════════════════════════
- Si la section des activités/centres d'intérêt est vide, incomplète ou très peu fournie dans le CV brut, tu dois DÉDUIRE et ENRICHIS-la intelligemment de manière réaliste et valorisante en fonction du profil et du secteur d'activité du candidat.
- Propose 2 à 4 activités réalistes qui valorisent le profil (ex: pour un profil informatique : 'Veille technologique et projets open-source', 'Jeux de stratégie ou d'échecs'. Pour un poste commercial : 'Sports collectifs', etc.).
- Chaque activité dans le tableau doit être une simple chaîne de caractères concise, percutante et professionnelle (ex: 'Pratique régulière de la course à pied', 'Bénévolat associatif', 'Veille constante sur les nouvelles technologies').
- Ne laisse JAMAIS le tableau d'activités vide si tu peux y ajouter des éléments pertinents qui renforcent l'aspect humain et équilibré du candidat.

Retourne UNIQUEMENT un objet JSON valide avec cette structure exacte, sans aucun texte d'accompagnement, sans bloc de code markdown (pas de \`\`\`json), et sans commentaire :
{
  "fullName": "",
  "jobTitle": "",
  "summary": "",
  "email": "",
  "phone": "",
  "location": "",
  "linkedin": "",
  "skills": "",
  "experiences": [
    {
      "jobTitle": "",
      "company": "",
      "location": "",
      "startDate": "",
      "endDate": "",
      "description": ""
    }
  ],
  "educations": [
    {
      "degree": "",
      "institution": "",
      "location": "",
      "startDate": "",
      "endDate": "",
      "description": ""
    }
  ],
  "projects": [
    {
      "name": "",
      "role": "",
      "date": "",
      "description": ""
    }
  ],
  "activities": []
}`
            },
            {
              role: "user",
              content: `Voici le texte brut extrait de mon CV PDF. Analyse-le et retourne le JSON structuré :\n\n${rawText}`
            }
          ],
          temperature: 0.25,
          response_format: { type: "json_object" },
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error("Mistral API error:", response.status, errorText);
        return new Response(
          JSON.stringify({
            error: `Mistral API error (${response.status})`,
            details: errorText,
          }),
          {
            status: response.status,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }

      const mistralData = await response.json();
      const content = mistralData.choices[0].message.content.trim();
      
      responseData = {
        success: true,
        data: JSON.parse(content),
      };

    } else if (action === "polish_text") {
      const { text, systemContent } = body;
      if (!text || !systemContent) {
        return new Response(
          JSON.stringify({ error: "Missing text or systemContent" }),
          {
            status: 400,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }

      console.log(`Polishing text for user: ${user.id} (${text.substring(0, 50)}...)`);

      // Call Mistral API
      const response = await fetch("https://api.mistral.ai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${mistralApiKey}`,
        },
        body: JSON.stringify({
          model: "mistral-small-latest",
          messages: [
            {
              role: "system",
              content: systemContent,
            },
            {
              role: "user",
              content: `Reformule et améliore ce texte/résumé pour un CV :\n\n${text}`
            }
          ],
          temperature: 0.3,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error("Mistral API error during polish:", response.status, errorText);
        return new Response(
          JSON.stringify({
            error: `Mistral API error (${response.status})`,
            details: errorText,
          }),
          {
            status: response.status,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }

      const mistralData = await response.json();
      responseData = {
        success: true,
        polishedText: mistralData.choices[0].message.content.trim(),
      };

    } else {
      return new Response(JSON.stringify({ error: "Invalid action" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    return new Response(JSON.stringify(responseData), {
      status: 200,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });

  } catch (error) {
    console.error("Internal server error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
