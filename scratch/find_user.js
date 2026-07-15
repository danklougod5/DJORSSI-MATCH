const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function run() {
  console.log("Searching for user containing 'dody' or 'Dody'...");
  const { data: profiles, error } = await supabase
    .from('profiles')
    .select('id, full_name, is_premium, premium_until, fcm_token')
    .ilike('full_name', '%dody%');

  if (error) {
    console.error("Error fetching profiles:", error.message);
    return;
  }

  console.log(`Found ${profiles.length} profiles matching 'dody':`);
  for (const p of profiles) {
    console.log(`- ID: ${p.id}`);
    console.log(`  Name: ${p.full_name}`);
    console.log(`  Premium: ${p.is_premium}`);
    console.log(`  Premium Until: ${p.premium_until}`);
    console.log(`  FCM Token set: ${!!p.fcm_token}`);
    
    // Check their alerts
    const { data: alerts, error: alertError } = await supabase
      .from('job_alerts')
      .select('*')
      .eq('user_id', p.id);
      
    if (alertError) {
      console.error(`  Error fetching alerts:`, alertError.message);
    } else {
      console.log(`  Alerts (${alerts.length}):`);
      alerts.forEach(a => {
        console.log(`    - ID: ${a.id} | Sectors: ${JSON.stringify(a.sectors)} | Active: ${a.is_active}`);
      });
    }
  }
}

run();
