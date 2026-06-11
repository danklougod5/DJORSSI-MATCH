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
              content: `Tu es un expert en extraction et structuration de données de CV. Analyse le texte brut suivant extrait d'un CV PDF et retourne un JSON structuré avec EXACTEMENT les champs demandés.

Voici les consignes strictes pour structurer et améliorer les données :

1. INFOS PERSONNELLES & ACCROCHE :
- Extrais proprement le nom complet (fullName), le titre du poste recherché ou actuel (jobTitle), et un résumé de profil percutant (summary).
- Si le résumé est manquant ou trop court, rédige un résumé professionnel et chaleureux de 2-3 phrases en français en te basant sur le profil, le métier et l'expérience du candidat.

2. SÉPARATION POSTE / ENTREPRISE :
- Dans la liste des expériences ("experiences"), sépare rigoureusement le titre du poste (jobTitle) et le nom de l'entreprise (company).
- Ne mets JAMAIS le nom de l'entreprise ou les dates dans le champ "jobTitle". (Exemple : Si le texte brut dit "Développeur chez Orange", "jobTitle" doit être "Développeur" et "company" doit être "Orange"). Si l'entreprise n'est pas claire ou absente, laisse "company" vide "".

3. REFORMULATION PROFESSIONNELLE & VERBES D'ACTION :
- Nettoie et réécris les descriptions d'expériences ("description") sous forme de réalisations claires en français.
- Chaque point doit commencer par un verbe d'action au participe présent ou un nom d'action (ex: "Conception de...", "Gestion de...", "Optimisation de...").
- Formate-les obligatoirement sous forme de liste avec des puces : "• Réalisation 1\n• Réalisation 2".

4. CORRECTION DES FAUTES D'EXTRACTION DE TEXTE :
- Corrige automatiquement les coupures de mots, les apostrophes manquantes (ex: remplace "dAudit" par "d'Audit", "lEpargne" par "l'Epargne", "lAdministration" par "l'Administration"), les fautes d'orthographe et les caractères corrompus issus de la lecture brute du PDF.

5. NORMALISATION DES DATES :
- Formate les dates de façon homogène (ex: "Jan 2020", "2020", "2020 - 2023").
- Si le poste est occupé actuellement (ex: "depuis 2022", "présent", "actuel"), indique strictement "Présent" en date de fin (endDate).

6. COMPÉTENCES (SKILLS) :
- Regroupe et nettoie les compétences pour en faire une liste ordonnée et lisible avec des puces (ex: "• Flutter & Dart\n• State Management (Bloc, Riverpod)\n• Firebase & Supabase").

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
          temperature: 0.1,
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
