import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { Resend } from "npm:resend";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const resend = new Resend(Deno.env.get("RESEND_API_KEY") || "re_test_key");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    // Get the User checking the auth header
    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser();

    // Verify authentication
    if (authError || !user) {
      console.error("Auth error:", authError);
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Parse the request body
    const { jobTitle, jobCompany, cvUrl, message, userName } = await req.json();

    if (!cvUrl || !jobTitle) {
      return new Response(
        JSON.stringify({ error: "Missing required fields (cvUrl, jobTitle)" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // 1. Fetch the PDF from the provided URL
    console.log(`Fetching CV from: ${cvUrl}`);
    const cvResponse = await fetch(cvUrl);
    if (!cvResponse.ok) {
        throw new Error(`Failed to fetch CV file from the URL: ${cvUrl}`);
    }
    const cvArrayBuffer = await cvResponse.arrayBuffer();
    const cvBuffer = new Uint8Array(cvArrayBuffer);
    
    // We convert it to base64 for Resend
    let binary = '';
    const bytes = new Uint8Array(cvBuffer);
    for (let i = 0; i < bytes.byteLength; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    const cvBase64 = btoa(binary);

    // 2. Prepare the Email content
    const applicantName = userName || user.email?.split("@")[0] || "Un candidat";
    // We use the provided premium message or a default standard message (Zéro friction mode)
    const emailBody = message 
        ? message 
        : `Bonjour,\n\nSuite à votre annonce pour le poste de ${jobTitle} chez ${jobCompany || "votre entreprise"}, je vous soumets ma candidature.\n\nMon profil correspond à vos critères et vous trouverez mon CV en pièce jointe pour plus de détails sur mon parcours.\n\nCordialement,\n${applicantName}`;

    // 3. Send email via Resend
    console.log(`Sending email for job: ${jobTitle} with CV attachment...`);
    const { data: resendData, error: resendError } = await resend.emails.send({
      from: "Djossi Match <onboarding@resend.dev>", // TODO: Replace with your actual verified domain in production
      to: ["danklougod5@gmail.com"], // Hardcoded for testing as requested
      subject: `Candidature : ${jobTitle} - ${applicantName}`,
      text: emailBody,
      attachments: [
        {
          filename: `CV_${applicantName.replace(/\\s+/g, "_")}.pdf`,
          content: cvBase64,
        },
      ],
    });

    if (resendError) {
      console.error("Resend error:", resendError);
      throw new Error(`Erreur lors de l'envoi de l'email: ${resendError.message}`);
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "Email envoyé avec succès !",
        resendData 
      }),
      { status: 200, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  } catch (error) {
    console.error("Internal Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
