const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

const dodyEmail = "danklougod5@gmail.com";
const dodyPassword = "Arielle@008";

const adminEmail = "admin@djossimatch.ci";
const adminPassword = "Djorssi2026!";

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function run() {
  try {
    // 1. Log in as Dody
    console.log(`1. Logging in as user Dody (${dodyEmail})...`);
    const supabaseDody = createClient(supabaseUrl, supabaseAnonKey);
    const { data: dodyAuth, error: dodyAuthError } = await supabaseDody.auth.signInWithPassword({
      email: dodyEmail,
      password: dodyPassword
    });

    if (dodyAuthError) {
      throw new Error(`Dody auth failed: ${dodyAuthError.message}`);
    }

    // 2. Set alert for Dody (authenticated as Dody, so RLS passes)
    console.log("2. Upserting 'Informatique' alert for Dody...");
    const { error: alertError } = await supabaseDody
      .from('job_alerts')
      .upsert({
        user_id: dodyAuth.user.id,
        sectors: ["Informatique"],
        is_active: true,
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id' });
        
    if (alertError) {
      throw new Error(`Failed to set alert: ${alertError.message}`);
    }
    console.log("Job alert configured successfully.");

    // 3. Log in as Admin
    console.log(`\n3. Logging in as admin user (${adminEmail})...`);
    const supabaseAdmin = createClient(supabaseUrl, supabaseAnonKey);
    const { data: adminAuth, error: adminAuthError } = await supabaseAdmin.auth.signInWithPassword({
      email: adminEmail,
      password: adminPassword
    });

    if (adminAuthError) {
      throw new Error(`Admin auth failed: ${adminAuthError.message}`);
    }

    // 4. Countdown warning
    console.log("\n=======================================================");
    console.log("⚠️ ATTENTION : Veuillez fermer l'application ou la mettre en arrière-plan");
    console.log("et VERROUILLER votre iPhone maintenant !");
    console.log("=======================================================\n");

    for (let i = 5; i > 0; i--) {
      console.log(`Envoi de la notification dans ${i} secondes...`);
      await delay(1000);
    }
    console.log("🚀 Envoi en cours...");

    // 5. Trigger alert notification for job in Informatique
    const targetJobId = "90b3a849-767b-42b7-bc5d-5fa069d191eb"; // "Développeur Mobile Senior" (tag: Informatique)
    const { data: funcResult, error: funcError } = await supabaseAdmin.functions.invoke('notify-job-alerts', {
      body: { job_id: targetJobId },
      headers: {
        Authorization: `Bearer ${adminAuth.session.access_token}`
      }
    });

    if (funcError) {
      console.error("Function error details:", funcError);
      throw new Error(`Edge Function invocation failed: ${funcError.message}`);
    }

    console.log("\nSuccess! Edge Function Response:");
    console.log(JSON.stringify(funcResult, null, 2));

    // 6. Clean up Dody's alert
    console.log("\n6. Cleaning up Dody's alert...");
    const { error: deleteError } = await supabaseDody
      .from('job_alerts')
      .delete()
      .eq('user_id', dodyAuth.user.id);

    if (deleteError) {
      console.error("Failed to delete alert during cleanup:", deleteError.message);
    } else {
      console.log("Alert removed successfully. Database is clean.");
    }

  } catch (error) {
    console.error("Error occurred:", error);
  }
}

run();
