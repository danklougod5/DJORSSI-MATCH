import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const GENIUS_PAY_SECRET_KEY = Deno.env.get("GENIUS_PAY_SECRET_KEY");
    const GENIUS_PAY_PUBLIC_KEY = Deno.env.get("GENIUS_PAY_PUBLIC_KEY");
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!GENIUS_PAY_SECRET_KEY || !GENIUS_PAY_PUBLIC_KEY) {
      throw new Error("Genius Pay keys not configured in Edge Function environment");
    }

    // Initialize Supabase client with the user's Auth token
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), { 
        status: 401, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      });
    }

    // Use anon key and the user's token for auth-related operations
    // This avoids the ES256 JWT algorithm issue in the Deno runtime
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      console.error("Auth Error:", authError);
      return new Response(JSON.stringify({ error: "Unauthorized", details: authError }), { 
        status: 401, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      });
    }

    // Create admin client for database operations
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Parse request body
    const { amount, customer } = await req.json();
    
    // Call Genius Pay API
    const response = await fetch("https://pay.genius.ci/api/v1/merchant/payments", {
      method: "POST",
      headers: {
        "X-API-Key": GENIUS_PAY_PUBLIC_KEY,
        "X-API-Secret": GENIUS_PAY_SECRET_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amount,
        description: "Abonnement Djorssi Premium",
        customer: {
          name: customer.name,
          email: customer.email,
          phone: customer.phone,
        },
        success_url: "https://djorssi-match.com/payment/success",
        error_url: "https://djorssi-match.com/payment/error",
        metadata: {
          user_id: user.id
        }
      }),
    });

    const result = await response.json();

    if (!result.success) {
      return new Response(JSON.stringify(result), { 
        status: 400, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      });
    }

    // Store in payments table using adminClient
    const { error: dbError } = await adminClient
      .from("payments")
      .insert({
        user_id: user.id,
        pay_token: result.data.reference,
        amount: amount,
        gateway: "GENIUS_PAY",
        status: "PENDING",
      });

    if (dbError) {
      console.error("DB Insertion Error:", dbError);
    }

    return new Response(JSON.stringify(result), {
      status: 201,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error: any) {
    console.error("Function Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
