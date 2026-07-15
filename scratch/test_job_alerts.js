const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error("Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY in web-app/.env");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

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

    // 2. Fetch some jobs
    console.log("\n2. Fetching recent jobs...");
    const { data: jobs, error: jobsError } = await supabase
      .from('jobs')
      .select('id, job_title, tags, company_name')
      .order('created_at', { ascending: false })
      .limit(5);

    if (jobsError) {
      throw new Error(`Jobs fetch failed: ${jobsError.message}`);
    }

    console.log("Recent jobs:");
    jobs.forEach(j => {
      console.log(`- ID: ${j.id} | Title: ${j.job_title} | Tags: ${JSON.stringify(j.tags)} | Company: ${j.company_name}`);
    });

    if (jobs.length === 0) {
      console.log("No jobs found in the database. Please add a job first.");
      return;
    }

    // 3. Fetch profiles and check FCM tokens / Premium
    console.log("\n3. Fetching profiles with active alerts...");
    const { data: alerts, error: alertsError } = await supabase
      .from('job_alerts')
      .select('user_id, sectors, is_active')
      .eq('is_active', true);

    if (alertsError) {
      throw new Error(`Alerts fetch failed: ${alertsError.message}`);
    }

    console.log(`Found ${alerts.length} active job alerts.`);

    for (const alert of alerts) {
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('id, full_name, is_premium, premium_until, fcm_token')
        .eq('id', alert.user_id)
        .single();

      if (profileError) {
        console.error(`  Error fetching profile for user ${alert.user_id}:`, profileError.message);
        continue;
      }

      console.log(`  User: ${profile.full_name || 'No Name'} (${profile.id})`);
      console.log(`    Premium: ${profile.is_premium} | FCM Token set: ${!!profile.fcm_token}`);
      console.log(`    Alert sectors: ${JSON.stringify(alert.sectors)}`);
    }

    // 3.5 Temporarily set a dummy fcm_token for the premium user to test FCM push notification
    const targetUserId = 'b6f516d5-56f0-41d0-80b0-7cbe577d3a76';
    console.log(`\n3.5 Temporarily setting fcm_token for user ${targetUserId}...`);
    const { error: updateError } = await supabase
      .from('profiles')
      .update({ fcm_token: 'dummy_fcm_token_for_testing_purposes' })
      .eq('id', targetUserId);

    if (updateError) {
      console.warn("Could not update fcm_token (likely RLS):", updateError.message);
    } else {
      console.log("Successfully set fcm_token to dummy value.");
    }

    // 4. Trigger notify-job-alerts for the most recent job
    const targetJob = jobs[0];
    console.log(`\n4. Triggering 'notify-job-alerts' for Job ID: ${targetJob.id} ("${targetJob.job_title}")...`);
    
    const { data: funcResult, error: funcError } = await supabase.functions.invoke('notify-job-alerts', {
      body: { job_id: targetJob.id },
      headers: {
        Authorization: `Bearer ${authData.session.access_token}`
      }
    });

    // 4.5 Clean up fcm_token
    console.log(`\n4.5 Restoring fcm_token to null for user ${targetUserId}...`);
    const { error: restoreError } = await supabase
      .from('profiles')
      .update({ fcm_token: null })
      .eq('id', targetUserId);

    if (restoreError) {
      console.error("Failed to restore fcm_token:", restoreError.message);
    } else {
      console.log("Successfully restored fcm_token to null.");
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

    console.log("Edge Function Response:");
    console.log(JSON.stringify(funcResult, null, 2));

  } catch (error) {
    console.error("Error occurred during execution:", error);
  }
}

run();
