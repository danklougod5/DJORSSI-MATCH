import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GENIUS_PAY_WEBHOOK_SECRET = Deno.env.get("GENIUS_PAY_WEBHOOK_SECRET") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function verifySignature(payload: string, signature: string, timestamp: string, secret: string) {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
        "raw",
        encoder.encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
    );
    
    const data = encoder.encode(timestamp + "." + payload);
    const signatureBuffer = await crypto.subtle.sign("HMAC", key, data);
    
    // Convert to hex
    const hashArray = Array.from(new Uint8Array(signatureBuffer));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    
    return hashHex === signature;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const signature = req.headers.get("X-Webhook-Signature");
    const timestamp = req.headers.get("X-Webhook-Timestamp");
    const event = req.headers.get("X-Webhook-Event");

    const rawBody = await req.text();
    const payload = JSON.parse(rawBody);

    // 1. Verify Signature (only if secret is configured)
    if (GENIUS_PAY_WEBHOOK_SECRET && signature && timestamp) {
        const isValid = await verifySignature(rawBody, signature, timestamp, GENIUS_PAY_WEBHOOK_SECRET);
        if (!isValid) {
            console.error("Invalid GeniusPay Webhook Signature");
            return new Response("Invalid signature", { status: 401 });
        }
    }

    console.log(`Received GeniusPay Webhook: ${event}`, JSON.stringify(payload));

    // Get reference from payload
    const reference = payload.data?.reference || payload.data?.id?.toString();
    const status = payload.data?.status;

    if (event === "payment.success" || event === "payment.completed" || status === "completed") {
        // Find the payment record
        const { data: payment, error: pError } = await supabase
            .from("payments")
            .select("user_id, status, amount, metadata")
            .eq("pay_token", reference)
            .single();

        if (pError || !payment) {
            console.error("Payment record not found for reference:", reference);
            return new Response("Payment not found", { status: 200 });
        }

        if (payment.status === "SUCCESS") {
            return new Response("Already processed", { status: 200 });
        }

        // Update payment status
        await supabase
            .from("payments")
            .update({ status: "SUCCESS" })
            .eq("pay_token", reference);

        const payType = payment.metadata?.type;
        const amount = payment.amount;

        if (payType === "premium" || (amount >= 2000 && payType !== "extra_cv" && payType !== "modification")) {
            // Activate Premium for 30 days
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
                console.error("Error updating profile for premium:", uError);
                return new Response("Error updating profile", { status: 500 });
            }

            console.log(`Successfully activated premium for user: ${payment.user_id}`);
        } else if (payType === "extra_cv" || (amount === 500 && payType !== "modification")) {
            // Increment extra_cvs_purchased by 1
            // Fetch current extra_cvs_purchased first
            const { data: profile, error: profError } = await supabase
                .from("profiles")
                .select("extra_cvs_purchased")
                .eq("id", payment.user_id)
                .single();
            
            if (profError) {
                console.error("Error fetching profile:", profError);
                return new Response("Error fetching profile", { status: 500 });
            }

            const currentPurchased = profile?.extra_cvs_purchased || 0;

            const { error: uError } = await supabase
                .from("profiles")
                .update({
                    extra_cvs_purchased: currentPurchased + 1,
                })
                .eq("id", payment.user_id);

            if (uError) {
                console.error("Error updating profile for extra_cvs:", uError);
                return new Response("Error updating profile", { status: 500 });
            }
            console.log(`Successfully recorded extra CV slot purchase for user: ${payment.user_id}`);
        } else if (payType === "modification") {
            // Client checks payment table status
            console.log(`Successfully processed modification payment for user: ${payment.user_id}`);
        }
    } else if (event === "payment.failed" || status === "failed" || event === "payment.cancelled") {
        await supabase
            .from("payments")
            .update({ status: "FAILED" })
            .eq("pay_token", reference);
    } else {
        console.log(`Unhandled webhook event: ${event}, status: ${status}, reference: ${reference}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error: any) {
    console.error("Webhook Processing Error:", error.message);
    return new Response("Internal Server Error", { status: 500 });
  }
});
