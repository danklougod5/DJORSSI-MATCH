import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
);

async function listNonPremiumUsers() {
  console.log('=== UTILISATEURS NON-PREMIUM ===\n');

  const { data, error } = await supabase
    .from('profiles')
    .select('id, full_name, email, is_premium, premium_until, created_at')
    .eq('is_premium', false)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Erreur:', error.message);
    return;
  }

  if (!data || data.length === 0) {
    console.log('Aucun utilisateur non-premium trouvé.');
    return;
  }

  console.log(`${data.length} utilisateur(s) non-premium:\n`);
  for (const u of data) {
    console.log(`  ${u.full_name || 'Sans nom'} | ID: ${u.id} | Inscrit: ${u.created_at?.slice(0,10)}`);
  }

  console.log('\n\n💡 Une fois que tu as identifié le user_id, exécute dans le SQL Editor Supabase:');
  console.log('   https://supabase.com/dashboard/project/tbhxbfunyhbrctzfpkwf/sql\n');
  console.log("   UPDATE public.payments SET status = 'SUCCESS', updated_at = NOW() WHERE user_id = 'LE_USER_ID';");
  console.log("   UPDATE public.profiles SET is_premium = true, premium_until = NOW() + INTERVAL '30 days' WHERE id = 'LE_USER_ID';");
}

listNonPremiumUsers();
