const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function run() {
  try {
    console.log("1. Connexion en tant qu'administrateur...");
    const email = process.env.VITE_ADMIN_DEFAULT_EMAIL || "admin@djossimatch.ci";
    const password = process.env.VITE_ADMIN_DEFAULT_PASSWORD || "Djorssi2026!";
    
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (authError) {
      throw new Error(`Auth failed: ${authError.message}`);
    }

    console.log("Connecté avec succès:", authData.user.email);
    const token = authData.session.access_token;

    console.log("\n2. Envoi de la notification push...");
    // Le titre et message demandés par l'utilisateur
    const title = "ANNONCE : Y'a nouveauté ooh ! 🚀";
    const message = "C'est le week-end mais les recruteurs dorment pas hum ! Les jobs sont là là, viens les voir ne te fais pas devancer ! Bonne chance à tous !";

    const { data: funcResult, error: funcError } = await supabase.functions.invoke('send-broadcast-notification', {
      body: {
        title,
        message,
        target: "all",
        is_personal: true // Permet de personnaliser avec le prénom de chaque utilisateur
      },
      headers: {
        Authorization: `Bearer ${token}`
      }
    });

    if (funcError) {
      console.error("Détails de l'erreur de la fonction:", funcError);
      throw new Error(`Échec de l'appel à la Edge Function: ${funcError.message}`);
    }

    console.log("\nSuccès ! Réponse de la Edge Function :");
    console.log(JSON.stringify(funcResult, null, 2));

  } catch (error) {
    console.error("Une erreur est survenue pendant l'exécution :", error);
  }
}

run();
