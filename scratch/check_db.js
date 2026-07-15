const { createClient } = require('@supabase/supabase-client');
require('dotenv').config({ path: './web-app/.env' });

const supabase = createClient(
  process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY
);

async function checkProfiles() {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .limit(5);

  if (error) {
    console.error('Erreur:', error);
    return;
  }

  console.log('Colonnes trouvées:', Object.keys(data[0] || {}));
  console.log('Données des 5 premiers profils:');
  data.forEach(p => {
    console.log(`- ${p.full_name || 'Anonyme'}: Premium=${p.is_premium}, Validité=${p.premium_until}`);
  });

  const { count } = await supabase
    .from('profiles')
    .select('id', { count: 'exact', head: true })
    .eq('is_premium', true);
    
  console.log('Nombre total de Premium détectés par la base:', count);
}

checkProfiles();
