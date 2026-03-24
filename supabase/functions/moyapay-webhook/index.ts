import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const payload = await req.json();
    console.log("Received MoyaPay Webhook:", JSON.stringify(payload));

    const { idFromClient, status, amount } = payload;
    
    if (!idFromClient) {
      return new Response("Missing idFromClient", { status: 400 });
    }

    // MoyaPay Success Statuses
    const isSuccess = ["SUCCEED", "SUCCESSFUL", "SUCCESS", "COMPLETED"].includes(status);
    const isFailed = ["FAILED", "REJECTED", "CANCELLED"].includes(status);

    if (isSuccess) {
      // 1. Get transaction from DB
      const { data: payment, error: pError } = await supabase
        .from("payments")
        .select("user_id, status")
        .eq("pay_token", idFromClient)
        .single();

      if (pError || !payment) {
        console.error("Payment not found for token:", idFromClient);
        return new Response("Payment not found", { status: 404 });
      }

      if (payment.status === "SUCCESS") {
        return new Response("Already processed", { status: 200 });
      }

      // 2. Update Payment Status
      await supabase
        .from("payments")
        .update({ status: "SUCCESS" })
        .eq("pay_token", idFromClient);

      // 3. Activate Premium for 30 days
      const premiumUntil = new Date();
      premiumUntil.setDate(premiumUntil.getDate() + 30);

      const { error: uError } = await supabase
        .from("profiles")
        .update({
          is_premium: true,
          premium_until: premiumUntil.toISOString(),
        })
        .eq("id", payment.user_id);

      if (uError) {
        console.error("Error updating profile:", uError);
        return new Response("Error updating profile", { status: 500 });
      }

      console.log(`Successfully activated premium for user: ${payment.user_id}`);
    } else if (isFailed) {
      await supabase
        .from("payments")
        .update({ status: "FAILED" })
        .eq("pay_token", idFromClient);
      
      console.log(`Payment failed for token: ${idFromClient}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Webhook Error:", error);
    return new Response("Internal Server Error", { status: 500 });
  }
});
