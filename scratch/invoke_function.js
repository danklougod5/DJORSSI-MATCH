require('dotenv').config({ path: 'app/.env' });
const fetch = require('node-fetch') || globalThis.fetch;

async function run() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;
  if (!url || !key) {
    console.error("Missing credentials");
    process.exit(1);
  }

  // Get a recent job to trigger
  const supabaseUrl = `${url}/rest/v1/jobs?select=id,tags&order=created_at.desc&limit=1`;
  const jResponse = await fetch(supabaseUrl, {
    headers: {
      'apikey': key,
      'Authorization': `Bearer ${key}`
    }
  });
  const jobs = await jResponse.json();
  if (!jobs || jobs.length === 0) {
    console.log("No jobs found");
    return;
  }
  const jobId = jobs[0].id;
  console.log(`Triggering for job ${jobId}...`);

  const funcUrl = `${url}/functions/v1/notify-job-alerts`;
  const response = await fetch(funcUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${key}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ job_id: jobId })
  });

  console.log(`Status: ${response.status}`);
  const text = await response.text();
  console.log("Response:", text);
}

run().catch(console.error);
