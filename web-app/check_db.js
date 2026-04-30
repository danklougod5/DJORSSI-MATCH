import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config({ path: './.env' });

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
);

async function checkProfiles() {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .limit(5);

    if (error) {
      console.error('Erreur Supabase:', error.message);
      return;
    }

    if (!data || data.length === 0) {
      console.log('Aucun profil trouvé dans la table profiles.');
      return;
    }

    console.log('--- DIAGNOSTIC ---');
    console.log('Colonnes disponibles:', Object.keys(data[0]));
    
    console.log('\nÉchantillon de profils:');
    data.forEach(p => {
      console.log(`- ${p.full_name || 'Sans Nom'}: is_premium=${p.is_premium}, premium_until=${p.premium_until}`);
    });

    const { count } = await supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .eq('is_premium', true);
      
    console.log('\nNombre total de Premium en base:', count);
    console.log('-------------------');
  } catch (err) {
    console.error('Erreur fatale:', err.message);
  }
}

checkProfiles();
