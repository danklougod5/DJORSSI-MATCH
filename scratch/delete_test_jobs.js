const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function run() {
  try {
    console.log("1. Finding jobs with 'test' in the title...");
    const { data: jobs, error: selectError } = await supabase
      .from('jobs')
      .select('id, job_title, company_name, created_at')
      .ilike('job_title', '%test%');

    if (selectError) {
      throw selectError;
    }

    console.log(`Found ${jobs.length} test jobs:`);
    for (const job of jobs) {
      console.log(`- ID: ${job.id} | Title: "${job.job_title}" | Company: "${job.company_name}" | Created: ${job.created_at}`);
    }

    if (jobs.length === 0) {
      console.log("No test jobs found to delete.");
      return;
    }

    console.log("\n2. Deleting these test jobs...");
    const jobIds = jobs.map(j => j.id);
    const { error: deleteError } = await supabase
      .from('jobs')
      .delete()
      .in('id', jobIds);

    if (deleteError) {
      throw deleteError;
    }

    console.log("Successfully deleted all test jobs!");

  } catch (error) {
    console.error("Error occurred:", error);
  }
}

run();
