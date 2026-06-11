import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { Resend } from "npm:resend";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { JWT } from "https://esm.sh/google-auth-library@9.0.0";

const resend = new Resend(Deno.env.get("RESEND_API_KEY") || "");

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://djossi-match.vercel.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders }
      });
    }

    const token = authHeader.replace('Bearer ', '').trim();
    let isServiceRole = false;

    try {
      const payloadBase64 = token.split('.')[1];
      const payloadString = atob(payloadBase64);
      const payload = JSON.parse(payloadString);
      if (payload.role === 'service_role') {
        isServiceRole = true;
      }
    } catch (e) {
      console.error("Error decoding token:", e);
    }

    if (!isServiceRole) {
      const supabaseClient = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        { global: { headers: { Authorization: authHeader } } }
      );

      const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token);
      if (authError || !user) {
        return new Response(JSON.stringify({ error: 'Unauthorized', details: authError?.message || 'No user found' }), {
          status: 401,
          headers: { "Content-Type": "application/json", ...corsHeaders }
        });
      }
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Get the job_id from the request (either from a trigger via JSON body or manual call)
    const { job_id } = await req.json();

    if (!job_id) {
       return new Response(JSON.stringify({ error: "No job_id provided" }), { status: 400 });
    }

    // 1. Fetch Job details
    const { data: job, error: jobError } = await supabaseAdmin
      .from('jobs')
      .select('*')
      .eq('id', job_id)
      .single();

    if (jobError || !job) {
      throw new Error(`Job not found: ${jobError?.message}`);
    }

    if (job.is_approved === false) {
      console.log(`Job ${job_id} is not approved, skip notifications.`);
      return new Response(JSON.stringify({ message: "Job not approved, skipping" }), { 
        status: 200, 
        headers: { "Content-Type": "application/json", ...corsHeaders } 
      });
    }

    const jobTags = job.tags || [];
    if (jobTags.length === 0) {
       console.log("Job has no tags/sectors, skip notification.");
       return new Response(JSON.stringify({ message: "No tags on job, skipping" }), { status: 200 });
    }

    // 2. Find matching users (both active alerts and profile skills fallback)
    const { data: alerts, error: alertError } = await supabaseAdmin
      .from('job_alerts')
      .select('user_id, sectors')
      .eq('is_active', true)
      .overlaps('sectors', jobTags);

    if (alertError) {
      throw new Error(`Error fetching alerts: ${alertError.message}`);
    }

    // Query all premium profiles with matching skills
    const { data: premiumProfiles, error: profileErr } = await supabaseAdmin
      .from('profiles')
      .select('id, skills')
      .eq('is_premium', true)
      .overlaps('skills', jobTags);
      
    if (profileErr) {
      console.error(`Error fetching premium profiles fallback: ${profileErr.message}`);
    }

    // Query all users who have an alerts configuration
    const { data: allAlertUsers } = await supabaseAdmin
      .from('job_alerts')
      .select('user_id');

    const usersWithAlertsRow = new Set(allAlertUsers ? allAlertUsers.map(a => a.user_id) : []);

    // Build the consolidated list of users to notify
    const alertsToNotify: { user_id: string, sectors: string[] }[] = [];

    // Add users from job_alerts
    if (alerts) {
      alerts.forEach(alert => {
        alertsToNotify.push({
          user_id: alert.user_id,
          sectors: alert.sectors || []
        });
      });
    }

    // Add users from profiles fallback
    if (premiumProfiles) {
      const alreadyAdded = new Set(alertsToNotify.map(a => a.user_id));
      premiumProfiles.forEach(p => {
        if (!alreadyAdded.has(p.id) && !usersWithAlertsRow.has(p.id)) {
          alertsToNotify.push({
            user_id: p.id,
            sectors: p.skills || []
          });
        }
      });
    }

    if (alertsToNotify.length === 0) {
      console.log("No matching alerts or profile fallbacks found.");
      return new Response(JSON.stringify({ message: "No matching alerts or fallbacks" }), { 
        status: 200,
        headers: corsHeaders
      });
    }

    // 2.5 Prepare Firebase Service Account and Access Token for FCM notifications
    let accessToken: string | null = null;
    let projectId: string | null = null;
    try {
      const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
      if (serviceAccountRaw) {
        const serviceAccount = JSON.parse(serviceAccountRaw);
        const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n');
        projectId = serviceAccount.project_id;
        
        const jwtClient = new JWT(
          serviceAccount.client_email,
          undefined,
          privateKey,
          ['https://www.googleapis.com/auth/cloud-platform']
        );
        const gTokens = await jwtClient.authorize();
        accessToken = gTokens.access_token ?? null;
        console.log("FCM access token generated successfully.");
      } else {
        console.warn("FIREBASE_SERVICE_ACCOUNT is not set. FCM notifications will be skipped.");
      }
    } catch (e: any) {
      console.error("Failed to initialize FCM authentication:", e);
    }

    // 3. For each matching user, check premium status and send notifications
    const notifications = await Promise.all(alertsToNotify.map(async (alert) => {
        // Check if user is still premium
        const { data: profile, error: profileError } = await supabaseAdmin
          .from('profiles')
          .select('is_premium, premium_until, full_name, fcm_token')
          .eq('id', alert.user_id)
          .single();

        if (profileError || !profile) {
          console.error(`Could not find profile for user ${alert.user_id}`);
          return { user_id: alert.user_id, status: 'skipped', reason: 'No profile' };
        }

        const isPremium = profile.is_premium ?? false;
        const premiumUntil = profile.premium_until ? new Date(profile.premium_until) : null;
        const isStillPremium = isPremium && (!premiumUntil || premiumUntil > new Date());

        if (!isStillPremium) {
          console.log(`User ${alert.user_id} is no longer premium, skipping notification.`);
          return { user_id: alert.user_id, status: 'skipped', reason: 'Premium expired' };
        }

        // Send Email via Resend
        let emailStatus = 'skipped';
        let emailError = null;
        let resendId = null;

        try {
          // Get user email from auth.users (requires service role / admin)
          const { data: { user }, error: userError } = await supabaseAdmin.auth.admin.getUserById(alert.user_id);
          
          if (userError || !user || !user.email) {
            console.error(`Could not find email for user ${alert.user_id}`);
            emailStatus = 'error';
            emailError = 'No email found for user';
          } else {
            const senderEmail = Deno.env.get("SENDER_EMAIL") || "contact@djorssi-match.com";
            const { data, error: sendError } = await resend.emails.send({
              from: `Djorssi-Match <${senderEmail}>`,
              to: [user.email],
              subject: `Nouvelle offre : ${job.job_title} chez ${job.company_name}`,
              text: `Bonjour,\n\nUne nouvelle offre d'emploi correspondant à vos secteurs d'intérêt vient d'être publiée :\n\n- Poste: ${job.job_title}\n- Entreprise: ${job.company_name}\n- Lieu: ${job.location || 'Côte d\'Ivoire'}\n${job.salary_range ? `- Salaire: ${job.salary_range}\n` : ''}\nVoir l'offre sur Djorssi-Match : https://djorssi-match.vercel.app/jobs/${job.id}\n\nVous recevez cet email car vous avez activé les alertes emplois pour : ${alert.sectors.join(', ')}.`,
              html: `
                <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px;">
                  <h2 style="color: #f97316;">Nouveau Job Match !</h2>
                  <p>Bonjour,</p>
                  <p>Une nouvelle offre d'emploi correspondant à vos secteurs d'intérêt vient d'être publiée :</p>
                  <div style="background-color: #f8fafc; padding: 15px; border-radius: 8px; margin: 20px 0;">
                    <h3 style="margin-top: 0;">${job.job_title}</h3>
                    <p><strong>Entreprise:</strong> ${job.company_name}</p>
                    <p><strong>Lieu:</strong> ${job.location || 'Côte d\'Ivoire'}</p>
                    ${job.salary_range ? `<p><strong>Salaire:</strong> ${job.salary_range}</p>` : ''}
                  </div>
                  <a href="https://djorssi-match.vercel.app/jobs/${job.id}" style="display: inline-block; background-color: #f97316; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold;">Voir l'offre sur Djorssi-Match</a>
                  <p style="margin-top: 30px; font-size: 12px; color: #64748b;">
                    Vous recevez cet email car vous avez activé les alertes emplois pour : ${alert.sectors.join(', ')}. 
                    Vous pouvez désactiver ces alertes dans votre profil.
                  </p>
                </div>
              `,
            });

            if (sendError) {
              emailStatus = 'error';
              emailError = sendError;
            } else {
              emailStatus = 'success';
              resendId = data?.id;
            }
          }
        } catch (err: any) {
          emailStatus = 'error';
          emailError = err.message || err;
        }

        // Send Push Notification via FCM
        let fcmStatus = 'skipped';
        let fcmError = null;

        if (accessToken && projectId && profile.fcm_token) {
          try {
            const rawSector = alert.sectors.find((s: string) => jobTags.includes(s)) || "votre secteur";
            // Check if it starts with a vowel for de/d'
            const vowels = ['a', 'e', 'i', 'o', 'u', 'y', 'h', 'é', 'è', 'à', 'ù'];
            const firstLetter = rawSector.trim().toLowerCase().charAt(0);
            const sectorPhrase = vowels.includes(firstLetter) ? `d'${rawSector}` : `de ${rawSector}`;
            
            const title = `Nouvelle offre ${sectorPhrase} !`;
            const body = `Bonjour ${profile.full_name || 'utilisateur'}, une offre ${sectorPhrase} a été ajoutée. Viens voir l'offre !`;

            const fcmResponse = await fetch(
              `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
              {
                method: 'POST',
                headers: {
                  'Authorization': `Bearer ${accessToken}`,
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                  message: {
                    token: profile.fcm_token,
                    notification: { title, body },
                    data: { 
                      click_action: "FLUTTER_NOTIFICATION_CLICK",
                      job_id: String(job.id)
                    },
                    android: {
                      notification: {
                        channel_id: "high_importance_channel",
                        sound: "default"
                      }
                    },
                    apns: {
                      headers: {
                        "apns-push-type": "alert",
                        "apns-priority": "10"
                      },
                      payload: {
                        aps: {
                          alert: { title, body },
                          sound: "default",
                          badge: 1,
                          "mutable-content": 1,
                          "content-available": 1
                        }
                      }
                    }
                  },
                }),
              }
            );

            if (fcmResponse.ok) {
              fcmStatus = 'success';
            } else {
              const errBody = await fcmResponse.text();
              fcmStatus = 'error';
              fcmError = `FCM server returned status ${fcmResponse.status}: ${errBody}`;
              console.error(`FCM error for user ${alert.user_id}: ${fcmError}`);
            }
          } catch (e: any) {
            fcmStatus = 'error';
            fcmError = e.message || e;
            console.error(`Failed to send FCM to user ${alert.user_id}: ${e}`);
          }
        }

        // 4. Save notification in the database for in-app display
        let dbStatus = 'skipped';
        try {
          const { error: insertError } = await supabaseAdmin
            .from('notifications')
            .insert({
              target: alert.user_id,
              title: `Nouvelle offre: ${job.job_title}`,
              body: `${job.company_name} recrute pour ce poste. Venez vite découvrir l'offre !`,
            });
            
          if (insertError) {
             console.error(`Error inserting into notifications table for user ${alert.user_id}:`, insertError);
             dbStatus = 'error';
          } else {
             dbStatus = 'success';
          }
        } catch(e) {
          console.error(`Error saving notification for user ${alert.user_id}:`, e);
          dbStatus = 'error';
        }

        return { 
          user_id: alert.user_id, 
          email: { status: emailStatus, error: emailError, resend_id: resendId },
          fcm: { status: fcmStatus, error: fcmError },
          db: { status: dbStatus }
        };
      }));

      return new Response(JSON.stringify({ success: true, notifications }), { 
        status: 200, 
        headers: { "Content-Type": "application/json", ...corsHeaders } 
      });


  } catch (error) {
    console.error("Internal Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
