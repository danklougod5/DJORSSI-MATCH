const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseAnonKey);

const dodyId = 'c43f3caf-7f1d-4882-93c6-e7c4e778de36';

async function run() {
  try {
    console.log("1. Logging in as admin user...");
    const email = process.env.VITE_ADMIN_DEFAULT_EMAIL || "admin@djossimatch.ci";
    const password = process.env.VITE_ADMIN_DEFAULT_PASSWORD || "Djorssi2026!";
    
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (authError) {
      throw new Error(`Auth failed: ${authError.message}`);
    }

    console.log("Logged in successfully as:", authData.user.email);

    // 2. Fetch the target job
    console.log("\n2. Fetching recent job containing 'informatique' or similar...");
    const { data: jobs, error: jobsError } = await supabase
      .from('jobs')
      .select('id, job_title, tags, company_name')
      .order('created_at', { ascending: false })
      .limit(5);

    if (jobsError) {
      throw new Error(`Jobs fetch failed: ${jobsError.message}`);
    }

    // Find job with "Informatique , Télécoms"
    const targetJob = jobs.find(j => j.tags && j.tags.includes("Informatique , Télécoms")) || jobs[0];
    console.log(`Using Job: ID=${targetJob.id} | Title="${targetJob.job_title}" | Tags=${JSON.stringify(targetJob.tags)}`);

    // 3. Upsert a temporary active alert for Dody matching "Informatique , Télécoms"
    console.log(`\n3. Upserting temporary job alert for user Dody (${dodyId})...`);
    const { error: alertUpsertError } = await supabase
      .from('job_alerts')
      .upsert({
        user_id: dodyId,
        sectors: ["Informatique , Télécoms"],
        is_active: true,
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id' });

    if (alertUpsertError) {
      throw new Error(`Failed to upsert job alert for Dody: ${alertUpsertError.message}`);
    }
    console.log("Job alert upserted successfully.");

    // 4. Trigger notify-job-alerts for the target job
    console.log(`\n4. Invoking 'notify-job-alerts' for Job ID: ${targetJob.id}...`);
    const { data: funcResult, error: funcError } = await supabase.functions.invoke('notify-job-alerts', {
      body: { job_id: targetJob.id },
      headers: {
        Authorization: `Bearer ${authData.session.access_token}`
      }
    });

    // 5. Clean up Dody's alert (since Dody originally had 0 alerts)
    console.log(`\n5. Cleaning up temporary alert for user Dody (${dodyId})...`);
    const { error: deleteError } = await supabase
      .from('job_alerts')
      .delete()
      .eq('user_id', dodyId);

    if (deleteError) {
      console.error("Failed to delete temporary alert:", deleteError.message);
    } else {
      console.log("Successfully removed temporary job alert.");
    }

    if (funcError) {
      console.error("Function error details:", funcError);
      if (funcError.context && typeof funcError.context.json === 'function') {
        try {
          const errJson = await funcError.context.json();
          console.error("Function error JSON response:", errJson);
        } catch (e) {}
      }
      throw new Error(`Edge Function invocation failed: ${funcError.message}`);
    }

    console.log("\nSuccess! Edge Function Response:");
    console.log(JSON.stringify(funcResult, null, 2));

  } catch (error) {
    console.error("Error occurred during execution:", error);
  }
}

run();
