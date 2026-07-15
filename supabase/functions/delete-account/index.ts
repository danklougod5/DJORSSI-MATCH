import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const allowedOrigins = [
  "https://djossi-match.vercel.app",
  "https://www.djorssi-match.com",
  "https://djorssi-match.com",
];

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("Origin") || "";
  const allowedOrigin = allowedOrigins.includes(origin) ? origin : allowedOrigins[0];
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 2. Setup standard client to verify the user's current session
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.error("Missing Authorization header");
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // 2. Extract Token from Authorization header
    const token = authHeader.replace('Bearer ', '').trim();

    // 3. Setup standard client for verification (least privilege)
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    // 4. Get the User from the token
    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser(token);

    // 5. Setup client with the Admin/Service Role key to allow deleting users
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    if (authError || !user) {
      console.error("Auth Error:", authError?.message);
      return new Response(JSON.stringify({ 
        error: "Unauthorized", 
        details: authError?.message || "User not found" 
      }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    const userId = user.id;
    console.log(`Attempting to delete user: ${userId}`);

    // Read body for feedback
    let reason = "Non spécifié";
    let feedback = "";
    try {
      const body = await req.json();
      reason = body.reason || "Non spécifié";
      feedback = body.feedback || "";
    } catch (e) {
      console.log("No JSON body or failed to parse body:", e);
    }

    // Fetch user details from profile to log before deletion
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('phone_number')
      .eq('id', userId)
      .maybeSingle();

    const phone = profile?.phone_number || "";
    const email = user.email || "";

    // Save feedback to delete_account_feedback
    const { error: feedbackError } = await supabaseAdmin
      .from('delete_account_feedback')
      .insert({
        user_id: userId,
        phone_number: phone,
        email: email,
        reason: reason,
        feedback: feedback
      });
    
    if (feedbackError) {
      console.error("Error saving feedback to DB:", feedbackError);
    }

    // 4. Delete the user from Auth (This will trigger cascades if configured)
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (deleteError) {
      console.error("Error deleting user:", deleteError);
      throw deleteError;
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "Compte supprimé définitivement." 
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
