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

    // 2. Fetch the 2 most recent jobs from the database
    console.log("\n2. Fetching the 2 most recent jobs...");
    const { data: jobs, error: jobsError } = await supabaseDody
      .from('jobs')
      .select('id, job_title, tags')
      .order('created_at', { ascending: false })
      .limit(2);

    if (jobsError || !jobs || jobs.length < 2) {
      throw new Error(`Could not find 2 recent jobs: ${jobsError?.message}`);
    }

    const job1 = jobs[0];
    const job2 = jobs[1];
    console.log(`Job 1: ID=${job1.id} | Title="${job1.job_title}" | Tags=${JSON.stringify(job1.tags)}`);
    console.log(`Job 2: ID=${job2.id} | Title="${job2.job_title}" | Tags=${JSON.stringify(job2.tags)}`);

    // Combine tags to ensure Dody matches both
    const combinedSectors = Array.from(new Set([...(job1.tags || []), ...(job2.tags || [])])).filter(s => s && s.trim().length > 0);
    console.log(`\nCombined alert sectors for matching: ${JSON.stringify(combinedSectors)}`);

    // 3. Set alert for Dody (authenticated as Dody, so RLS passes)
    console.log("3. Configuring alert sectors for Dody...");
    const { error: alertError } = await supabaseDody
      .from('job_alerts')
      .upsert({
        user_id: dodyAuth.user.id,
        sectors: combinedSectors,
        is_active: true,
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id' });
        
    if (alertError) {
      throw new Error(`Failed to set alert: ${alertError.message}`);
    }
    console.log("Job alert configured successfully.");

    // 4. Log in as Admin
    console.log(`\n4. Logging in as admin user (${adminEmail})...`);
    const supabaseAdmin = createClient(supabaseUrl, supabaseAnonKey);
    const { data: adminAuth, error: adminAuthError } = await supabaseAdmin.auth.signInWithPassword({
      email: adminEmail,
      password: adminPassword
    });

    if (adminAuthError) {
      throw new Error(`Admin auth failed: ${adminAuthError.message}`);
    }

    // 5. Trigger first notification
    console.log(`\n5. Invoking 'notify-job-alerts' for Job 1: "${job1.job_title}"...`);
    const res1 = await supabaseAdmin.functions.invoke('notify-job-alerts', {
      body: { job_id: job1.id },
      headers: { Authorization: `Bearer ${adminAuth.session.access_token}` }
    });

    if (res1.error) {
      console.error("Job 1 function error:", res1.error);
    } else {
      console.log("Job 1 notification trigger sent successfully.");
    }

    // Wait 2 seconds before sending the second one
    console.log("\nWaiting 2 seconds before sending the second notification...");
    await delay(2000);

    // 6. Trigger second notification
    console.log(`6. Invoking 'notify-job-alerts' for Job 2: "${job2.job_title}"...`);
    const res2 = await supabaseAdmin.functions.invoke('notify-job-alerts', {
      body: { job_id: job2.id },
      headers: { Authorization: `Bearer ${adminAuth.session.access_token}` }
    });

    if (res2.error) {
      console.error("Job 2 function error:", res2.error);
    } else {
      console.log("Job 2 notification trigger sent successfully.");
    }

    // 7. Clean up Dody's alert
    console.log("\n7. Cleaning up Dody's alert...");
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
