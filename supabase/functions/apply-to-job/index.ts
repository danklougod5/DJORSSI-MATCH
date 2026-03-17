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
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "No Authorization header" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Use Service Role Key to verify the user - This is the most reliable way in Edge Functions
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const jwt = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabaseAdmin.auth.getUser(jwt);

    if (authError || !user) {
      console.error("Auth error details:", authError);
      return new Response(JSON.stringify({ 
        error: "Unauthorized", 
        details: authError?.message || "Invalid or expired token"
      }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Parse the request body
    const { jobTitle, jobCompany, cvUrl, message, userName, jobContactEmail } = await req.json();

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
    const userEmail = user.email || "";

    // We use the provided premium message or a default standard message (Zéro friction mode)
    const emailBody = message 
        ? message 
        : `Bonjour,\n\nSuite à votre annonce pour le poste de ${jobTitle} chez ${jobCompany || "votre entreprise"}, je vous soumets ma candidature.\n\nMon profil correspond à vos critères et vous trouverez mon CV en pièce jointe pour plus de détails sur mon parcours.\n\nCordialement,\n${applicantName}\nEmail: ${userEmail}`;

    // 3. Send email via Resend
    // NOTE: In testing mode with onboarding@resend.dev, we can ONLY send to the account owner
    const targetEmail = "danklougod5@gmail.com"; 
    console.log(`Sending email for job: ${jobTitle} to ${targetEmail} (original target was ${jobContactEmail})...`);
    
    const { data: resendData, error: resendError } = await resend.emails.send({
      from: `Djossi Match <onboarding@resend.dev>`, 
      to: [targetEmail], // Forçage pour le test
      reply_to: userEmail,
      subject: `Candidature : ${jobTitle} - ${applicantName}`,
      text: emailBody,
      attachments: [
        {
          filename: `CV_${applicantName.replace(/\s+/g, "_")}.pdf`,
          content: cvBase64,
        },
      ],
    });

    if (resendError) {
      console.error("Resend delivery error:", resendError);
      return new Response(JSON.stringify({ 
        error: "Resend error", 
        details: resendError.message,
        code: resendError.name
      }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    console.log("Resend success data:", resendData);

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
