const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function run() {
  try {
    console.log("1. Finding existing jobs mentioning 'lettre de motivation'...");
    
    // Fetch all jobs to inspect their descriptions (since ilike in Supabase might be limited)
    const { data: jobs, error: selectError } = await supabase
      .from('jobs')
      .select('id, job_title, description, requires_cover_letter');

    if (selectError) {
      throw selectError;
    }

    const targetJobs = [];
    const keywords = ["lettre de motivation", "lettre motivation", "demande de motivation", "lettre de de motivation"];
    
    for (const job of jobs) {
      const desc = (job.description || "").toLowerCase();
      const title = (job.job_title || "").toLowerCase();
      
      const requiresCL = keywords.some(kw => desc.includes(kw) || title.includes(kw));
      
      if (requiresCL && !job.requires_cover_letter) {
        targetJobs.push(job);
      }
    }

    console.log(`Found ${targetJobs.length} jobs that should require a cover letter but currently don't.`);
    
    if (targetJobs.length === 0) {
      console.log("No jobs need backfilling.");
      return;
    }

    console.log("\n2. Backfilling requires_cover_letter to true for these jobs...");
    let updatedCount = 0;
    
    for (const job of targetJobs) {
      const { error: updateError } = await supabase
        .from('jobs')
        .update({ 
          requires_cover_letter: true,
          cover_letter_instructions: "Veuillez fournir une lettre de motivation pour postuler à cette offre."
        })
        .eq('id', job.id);
        
      if (updateError) {
        console.error(`Failed to update job ${job.id}: ${updateError.message}`);
      } else {
        updatedCount++;
      }
    }

    console.log(`Successfully backfilled ${updatedCount}/${targetJobs.length} jobs in the database!`);

  } catch (error) {
    console.error("Error occurred:", error);
  }
}

run();
