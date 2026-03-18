import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { Resend } from "npm:resend";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const resend = new Resend(Deno.env.get("RESEND_API_KEY") || "");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
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

    const jobTags = job.tags || [];
    if (jobTags.length === 0) {
       console.log("Job has no tags/sectors, skip notification.");
       return new Response(JSON.stringify({ message: "No tags on job, skipping" }), { status: 200 });
    }

    // 2. Find matching users with active alerts
    // We look for users who have at least one of the job tags in their alert sectors
    const { data: alerts, error: alertError } = await supabaseAdmin
      .from('job_alerts')
      .select('user_id, sectors')
      .eq('is_active', true)
      .overlaps('sectors', jobTags);

    if (alertError) {
      throw new Error(`Error fetching alerts: ${alertError.message}`);
    }

    if (!alerts || alerts.length === 0) {
      console.log("No matching alerts found.");
      return new Response(JSON.stringify({ message: "No matching alerts" }), { status: 200 });
    }

    // 3. For each matching user, get their email and send notification
    const notifications = await Promise.all(alerts.map(async (alert) => {
      // Get user email from auth.users (requires service role / admin)
      const { data: { user }, error: userError } = await supabaseAdmin.auth.admin.getUserById(alert.user_id);
      
      if (userError || !user || !user.email) {
        console.error(`Could not find email for user ${alert.user_id}`);
        return { user_id: alert.user_id, status: 'error', error: 'No email' };
      }

      console.log(`Sending alert for job "${job.job_title}" to ${user.email}`);

      // Send Email via Resend
      const { data, error: sendError } = await resend.emails.send({
        from: `Djossi Match <onboarding@resend.dev>`,
        to: [user.email],
        subject: `Nouvelle offre : ${job.job_title} chez ${job.company_name}`,
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
            <a href="https://djossi-match.vercel.app/jobs/${job.id}" style="display: inline-block; background-color: #f97316; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold;">Voir l'offre sur Djossi Match</a>
            <p style="margin-top: 30px; font-size: 12px; color: #64748b;">
              Vous recevez cet email car vous avez activé les alertes emplois pour : ${alert.sectors.join(', ')}. 
              Vous pouvez désactiver ces alertes dans votre profil.
            </p>
          </div>
        `,
      });

      if (sendError) {
        return { user_id: alert.user_id, status: 'error', error: sendError };
      }
      return { user_id: alert.user_id, status: 'success', resend_id: data?.id };
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
