const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

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
    const token = authData.session.access_token;

    console.log("\n2. Invoking 'send-broadcast-notification' edge function...");
    const { data: funcResult, error: funcError } = await supabase.functions.invoke('send-broadcast-notification', {
      body: {
        title: "Test Djorssi Match 🚀",
        message: "Félicitations ! Les notifications push sur votre iPhone fonctionnent parfaitement. 🎉",
        target: "premium"
      },
      headers: {
        Authorization: `Bearer ${token}`
      }
    });

    if (funcError) {
      console.error("Function error details:", funcError);
      throw new Error(`Edge Function invocation failed: ${funcError.message}`);
    }

    console.log("\nSuccess! Edge Function Response:");
    console.log(JSON.stringify(funcResult, null, 2));

  } catch (error) {
    console.error("Error occurred during execution:", error);
  }
}

run();
