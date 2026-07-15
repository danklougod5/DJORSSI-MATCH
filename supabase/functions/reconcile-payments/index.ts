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
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const GENIUS_PAY_PUBLIC_KEY = Deno.env.get("GENIUS_PAY_PUBLIC_KEY");
    const GENIUS_PAY_SECRET_KEY = Deno.env.get("GENIUS_PAY_SECRET_KEY");

    if (!GENIUS_PAY_PUBLIC_KEY || !GENIUS_PAY_SECRET_KEY) {
      throw new Error("GeniusPay API keys not configured");
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Get all PENDING payments from our database
    const { data: pendingPayments, error: fetchError } = await supabase
      .from("payments")
      .select("id, user_id, pay_token, amount, gateway, status, created_at, metadata")
      .eq("status", "PENDING")
      .order("created_at", { ascending: false });

    if (fetchError) {
      throw new Error(`DB fetch error: ${fetchError.message}`);
    }

    if (!pendingPayments || pendingPayments.length === 0) {
      return new Response(JSON.stringify({
        message: "Aucun paiement en attente",
        reconciled: 0,
        abandoned: 0,
        still_pending: 0,
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 });
    }

    console.log(`Found ${pendingPayments.length} pending payment(s) to reconcile`);

    const results = {
      reconciled: [] as any[],    // Payments confirmed as SUCCESS by GeniusPay → activated
      abandoned: [] as any[],     // Payments confirmed as failed/expired by GeniusPay
      still_pending: [] as any[], // Still pending on GeniusPay side too
      errors: [] as any[],       // Errors during check
    };

    // 2. For each pending payment, check status on GeniusPay
    for (const payment of pendingPayments) {
      if (payment.gateway !== "GENIUS_PAY") {
        results.still_pending.push({ ref: payment.pay_token, reason: "Not GeniusPay gateway" });
        continue;
      }

      try {
        // Call GeniusPay API to check real transaction status
        const gpResponse = await fetch(
          `https://pay.genius.ci/api/v1/merchant/payments/${payment.pay_token}`,
          {
            method: "GET",
            headers: {
              "X-API-Key": GENIUS_PAY_PUBLIC_KEY,
              "X-API-Secret": GENIUS_PAY_SECRET_KEY,
              "Content-Type": "application/json",
            },
          }
        );

        if (!gpResponse.ok) {
          // If 404, the payment might not exist on GeniusPay (very old or test)
          if (gpResponse.status === 404) {
            // Mark as ABANDONED if older than 24 hours
            const createdAt = new Date(payment.created_at);
            const hoursAgo = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);

            if (hoursAgo > 24) {
              await supabase
                .from("payments")
                .update({ status: "ABANDONED", updated_at: new Date().toISOString() })
                .eq("id", payment.id);
              results.abandoned.push({ ref: payment.pay_token, reason: "Not found on GeniusPay, older than 24h" });
            } else {
              results.still_pending.push({ ref: payment.pay_token, reason: "Not found on GeniusPay yet" });
            }
            continue;
          }

          results.errors.push({ ref: payment.pay_token, error: `GeniusPay API returned ${gpResponse.status}` });
          continue;
        }

        const gpData = await gpResponse.json();
        const gpStatus = gpData.data?.status?.toLowerCase();

        console.log(`Payment ${payment.pay_token}: GeniusPay status = ${gpStatus}`);

        if (gpStatus === "completed" || gpStatus === "success") {
          // ✅ Payment was actually successful — activate premium!
          await supabase
            .from("payments")
            .update({ status: "SUCCESS", updated_at: new Date().toISOString() })
            .eq("id", payment.id);

          const payType = payment.metadata?.type;

          // Fetch dynamic pricing config from app_config (id = 1)
          const { data: config, error: configError } = await supabase
            .from("app_config")
            .select("premium_price_cfa, extra_cv_price_cfa")
            .eq("id", 1)
            .single();

          if (configError) {
            console.error("Error fetching app_config pricing for reconciliation:", configError);
          }

          const premiumPrice = config?.premium_price_cfa ?? 2000;
          const extraCvPrice = config?.extra_cv_price_cfa ?? 500;

          if (payType === "premium" || (payment.amount >= premiumPrice && payType !== "extra_cv" && payType !== "modification")) {
            const premiumUntil = new Date();
            premiumUntil.setDate(premiumUntil.getDate() + 30);

            await supabase
              .from("profiles")
              .update({
                is_premium: true,
                premium_until: premiumUntil.toISOString(),
              })
              .eq("id", payment.user_id);

            results.reconciled.push({
              ref: payment.pay_token,
              user_id: payment.user_id,
              amount: payment.amount,
              action: "premium_activated",
            });
          } else if (payType === "extra_cv" || (payment.amount === extraCvPrice && payType !== "modification")) {
            const { data: profile } = await supabase
              .from("profiles")
              .select("extra_cvs_purchased")
              .eq("id", payment.user_id)
              .single();

            await supabase
              .from("profiles")
              .update({ extra_cvs_purchased: (profile?.extra_cvs_purchased || 0) + 1 })
              .eq("id", payment.user_id);

            results.reconciled.push({
              ref: payment.pay_token,
              user_id: payment.user_id,
              amount: payment.amount,
              action: "extra_cv_added",
            });
          } else {
            results.reconciled.push({
              ref: payment.pay_token,
              user_id: payment.user_id,
              amount: payment.amount,
              action: "payment_marked_success",
            });
          }

        } else if (gpStatus === "failed" || gpStatus === "cancelled" || gpStatus === "expired") {
          // ❌ Payment failed or was cancelled — mark as failed
          await supabase
            .from("payments")
            .update({ status: "FAILED", updated_at: new Date().toISOString() })
            .eq("id", payment.id);

          results.abandoned.push({ ref: payment.pay_token, gp_status: gpStatus });

        } else {
          // ⏳ Still pending on GeniusPay too
          // If older than 48h and still pending on GeniusPay, mark as abandoned
          const createdAt = new Date(payment.created_at);
          const hoursAgo = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);

          if (hoursAgo > 48) {
            await supabase
              .from("payments")
              .update({ status: "ABANDONED", updated_at: new Date().toISOString() })
              .eq("id", payment.id);
            results.abandoned.push({ ref: payment.pay_token, reason: `Still pending after ${Math.round(hoursAgo)}h` });
          } else {
            results.still_pending.push({ ref: payment.pay_token, gp_status: gpStatus });
          }
        }

      } catch (err: any) {
        console.error(`Error checking payment ${payment.pay_token}:`, err.message);
        results.errors.push({ ref: payment.pay_token, error: err.message });
      }
    }

    const summary = {
      total_pending: pendingPayments.length,
      reconciled: results.reconciled.length,
      abandoned: results.abandoned.length,
      still_pending: results.still_pending.length,
      errors: results.errors.length,
      details: results,
    };

    console.log("Reconciliation complete:", JSON.stringify(summary));

    return new Response(JSON.stringify(summary), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error: any) {
    console.error("Reconciliation Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
