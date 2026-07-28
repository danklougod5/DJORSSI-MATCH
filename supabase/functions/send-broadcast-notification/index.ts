import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { JWT } from "https://esm.sh/google-auth-library@9.0.0"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-application-name',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  console.log(`[DEBUG] Requête reçue: ${req.method}`);

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json();
    const { title, message, target, is_personal } = body;
    console.log(`[DEBUG] Payload: title="${title}", target="${target}", is_personal=${is_personal}`);

    // 0. Vérifier l'authentification et les droits administrateur
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      console.error("Missing Authorization header");
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const token = authHeader.replace('Bearer ', '').trim();
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token);
    if (authError || !user) {
      console.error("Authentication failed:", authError?.message);
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 1. Initialiser le client Supabase Admin
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { data: callerProfile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single();

    if (profileError || !callerProfile?.is_admin) {
      console.error(`Forbidden broadcast attempt by user: ${user.id}`);
      return new Response(JSON.stringify({ error: "Forbidden: Admin privilege required" }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. Récupérer les tokens FCM et les profils
    console.log(`[DEBUG] Récupération des tokens...`);
    let query = supabaseAdmin.from('profiles').select('fcm_token, full_name').not('fcm_token', 'is', null)
    
    if (target === 'premium') {
      query = query.eq('is_premium', true)
    } else if (target && target !== 'all') {
      query = query.eq('id', target)
    }

    const { data: profiles, error: dbError } = await query
    
    if (dbError) throw new Error(`Erreur DB: ${dbError.message}`);

    const validProfiles = profiles?.filter(p => p.fcm_token !== null) || [];
    console.log(`[DEBUG] ${validProfiles.length} profils avec tokens trouvés.`);
    
    if (validProfiles.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'Aucun token trouvé.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2.5 Enregistrer la notification en base pour l'historique des utilisateurs
    console.log(`[DEBUG] Enregistrement de la notification en base...`);
    let dbBody = message;
    if (is_personal) {
      let formattedMsg = message;
      if (formattedMsg.length > 0) {
        const firstChar = formattedMsg.charAt(0);
        if (/[a-zA-ZÀ-ÿ]/.test(firstChar)) {
          formattedMsg = firstChar.toLowerCase() + formattedMsg.slice(1);
        }
      }
      dbBody = `{name}, ${formattedMsg}`;
    }

    const { error: insertError } = await supabaseAdmin
      .from('notifications')
      .insert([{ title, body: dbBody, target }]);
    
    if (insertError) {
      console.error(`Erreur enregistrement base: ${insertError.message}`);
      // On continue quand même l'envoi aux téléphones
    }

    // 3. Préparer le compte de service
    console.log(`[DEBUG] Préparation du compte de service Firebase...`);
    const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!serviceAccountRaw) throw new Error("Le secret FIREBASE_SERVICE_ACCOUNT est manquant.");

    const serviceAccount = JSON.parse(serviceAccountRaw);
    
    // Nettoyage de la clé privée (très important pour Deno)
    const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n');

    // 4. Authentification Google
    console.log(`[DEBUG] Authentification Google...`);
    const jwtClient = new JWT(
      serviceAccount.client_email,
      undefined,
      privateKey,
      ['https://www.googleapis.com/auth/cloud-platform']
    );
    
    const gTokens = await jwtClient.authorize();
    const accessToken = gTokens.access_token;
    console.log(`[DEBUG] Access Token obtenu avec succès.`);

    // 5. Envoi des notifications
    const projectId = serviceAccount.project_id;
    let successCount = 0;
    let failureCount = 0;

    console.log(`[DEBUG] Envoi de ${validProfiles.length} notifications...`);
    for (const profile of validProfiles) {
      const token = profile.fcm_token;
      let recipientBody = message;

      if (is_personal) {
        let firstName = '';
        if (profile.full_name) {
          const parts = profile.full_name.trim().split(/\s+/);
          if (parts.length > 0) {
            const rawName = parts[0];
            firstName = rawName.charAt(0).toUpperCase() + rawName.slice(1).toLowerCase();
          }
        }

        if (firstName) {
          let formattedMsg = message;
          if (formattedMsg.length > 0) {
            const firstChar = formattedMsg.charAt(0);
            if (/[a-zA-ZÀ-ÿ]/.test(firstChar)) {
              formattedMsg = firstChar.toLowerCase() + formattedMsg.slice(1);
            }
          }
          recipientBody = `${firstName}, ${formattedMsg}`;
        }
      }

      try {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token: token,
                notification: { title, body: recipientBody },
                data: { click_action: "FLUTTER_NOTIFICATION_CLICK" }
              },
            }),
          }
        );
        if (response.ok) successCount++; else failureCount++;
      } catch (e) {
        console.error(`Erreur d'envoi pour un token: ${e}`);
        failureCount++;
      }
    }

    console.log(`[DEBUG] Terminé: ${successCount} succès, ${failureCount} échecs.`);
    return new Response(JSON.stringify({ success: true, sent: successCount, failed: failureCount }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error: any) {
    console.error(`[FATAL ERROR] ${error.message}`);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
