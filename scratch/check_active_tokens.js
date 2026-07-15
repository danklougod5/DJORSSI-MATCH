const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function run() {
  try {
    console.log("Fetching profiles with non-null fcm_token...");
    const { data: profiles, error } = await supabase
      .from('profiles')
      .select('id, full_name, fcm_token, is_premium, premium_until')
      .not('fcm_token', 'is', null);

    if (error) {
      throw error;
    }

    console.log(`\nFound ${profiles.length} profiles with active FCM tokens:`);
    for (const p of profiles) {
      const isPremium = p.is_premium ?? false;
      const premiumUntil = p.premium_until ? new Date(p.premium_until) : null;
      const activePremium = isPremium && (!premiumUntil || premiumUntil > new Date());
      
      console.log(`- User ID: ${p.id}`);
      console.log(`  Name: ${p.full_name}`);
      console.log(`  Premium Active: ${activePremium} (is_premium: ${p.is_premium}, until: ${p.premium_until})`);
      console.log(`  Token: ${p.fcm_token.substring(0, 15)}...${p.fcm_token.substring(p.fcm_token.length - 15)}`);
      
      // Fetch alerts
      const { data: alerts } = await supabase
        .from('job_alerts')
        .select('sectors, is_active')
        .eq('user_id', p.id);
        
      if (alerts && alerts.length > 0) {
        console.log(`  Alerts: ${JSON.stringify(alerts)}`);
      } else {
        console.log(`  Alerts: None`);
      }
      console.log("-----------------------------------------");
    }

  } catch (error) {
    console.error("Error occurred:", error);
  }
}

run();
