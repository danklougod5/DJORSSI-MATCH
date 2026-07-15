const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseAnonKey);

const dodyId = 'c43f3caf-7f1d-4882-93c6-e7c4e778de36';

async function run() {
  const { data: profile, error } = await supabase
    .from('profiles')
    .select('fcm_token')
    .eq('id', dodyId)
    .single();

  if (error) {
    console.error("Error:", error.message);
    return;
  }

  console.log("Dody's token length:", profile.fcm_token ? profile.fcm_token.length : 0);
  console.log("Dody's token value:", profile.fcm_token);
}

run();
