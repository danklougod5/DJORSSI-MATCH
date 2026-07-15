const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'web-app/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

const dodyEmail = "danklougod5@gmail.com";
const dodyPassword = "Arielle@008";

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

    // 2. Fetch Dody's cv_url
    console.log("2. Fetching Dody's CV URL...");
    const { data: profile, error: profileError } = await supabaseDody
      .from('profiles')
      .select('cv_url, full_name, sexe')
      .eq('id', dodyAuth.user.id)
      .single();

    if (profileError || !profile || !profile.cv_url) {
      throw new Error(`Could not find CV URL: ${profileError?.message || 'No CV URL'}`);
    }

    console.log(`Using CV URL: ${profile.cv_url}`);

    // 3. Invoke 'apply-to-job' edge function with requiresCoverLetter = true
    console.log("\n3. Invoking 'apply-to-job' with cover letter required...");
    const { data: result, error: funcError } = await supabaseDody.functions.invoke('apply-to-job', {
      body: {
        jobTitle: "Développeur Mobile (Test Lettre)",
        jobCompany: "Djorssi Match Inc",
        cvUrl: profile.cv_url,
        userName: profile.full_name,
        userSexe: profile.sexe || "Homme",
        jobContactEmail: dodyEmail, // Send to yourself
        requiresCoverLetter: true,
        coverLetterInstructions: "Décrire vos compétences en Flutter et Dart.",
        jobDescription: "Nous recherchons un développeur Flutter passionné pour rejoindre notre équipe de test.",
        message: "Bonjour, veuillez trouver ci-joint ma candidature avec lettre de motivation."
      },
      headers: {
        Authorization: `Bearer ${dodyAuth.session.access_token}`
      }
    });

    if (funcError) {
      console.error("Function error details:", funcError);
      throw new Error(`Edge Function 'apply-to-job' failed: ${funcError.message}`);
    }

    console.log("\nSuccess! Edge Function Response:");
    console.log(JSON.stringify(result, null, 2));

  } catch (error) {
    console.error("Error occurred:", error);
  }
}

run();
