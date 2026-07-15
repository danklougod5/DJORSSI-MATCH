import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config({ path: './web-app/.env' });

// Use the anon key — works for reading payments via RLS bypass on profiles
// For writes, we need the service role key
const SUPABASE_URL = process.env.VITE_SUPABASE_URL;
const SUPABASE_KEY = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function listPendingPayments() {
  console.log('=== PAIEMENTS EN ATTENTE (PENDING) ===\n');

  const { data, error } = await supabase
    .from('payments')
    .select('id, user_id, pay_token, amount, gateway, status, created_at, metadata')
    .eq('status', 'PENDING')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Erreur:', error.message);
    return;
  }

  if (!data || data.length === 0) {
    console.log('Aucun paiement en attente trouvé.');
    return;
  }

  console.log(`${data.length} paiement(s) en attente:\n`);

  for (const p of data) {
    // Try to get the user's profile
    const { data: profile } = await supabase
      .from('profiles')
      .select('full_name, email, is_premium, premium_until')
      .eq('id', p.user_id)
      .single();

    console.log(`─────────────────────────────────`);
    console.log(`  Utilisateur : ${profile?.full_name || 'Inconnu'} (${profile?.email || 'N/A'})`);
    console.log(`  User ID     : ${p.user_id}`);
    console.log(`  Montant     : ${p.amount} XOF`);
    console.log(`  Type        : ${p.metadata?.type || 'premium'}`);
    console.log(`  Gateway     : ${p.gateway}`);
    console.log(`  Référence   : ${p.pay_token}`);
    console.log(`  Date        : ${p.created_at}`);
    console.log(`  Premium?    : ${profile?.is_premium ? 'OUI' : 'NON'}`);
    console.log(`  Expire      : ${profile?.premium_until || 'N/A'}`);
    console.log();
  }

  console.log('─────────────────────────────────');
  console.log('\n💡 Pour corriger, va dans le SQL Editor Supabase et exécute:');
  console.log('   https://supabase.com/dashboard/project/tbhxbfunyhbrctzfpkwf/sql\n');

  for (const p of data) {
    if (p.metadata?.type === 'premium' || (!p.metadata?.type && p.amount >= 2000)) {
      console.log(`-- Corriger le paiement de ${p.pay_token}:`);
      console.log(`UPDATE public.payments SET status = 'SUCCESS', updated_at = NOW() WHERE pay_token = '${p.pay_token}';`);
      console.log(`UPDATE public.profiles SET is_premium = true, premium_until = NOW() + INTERVAL '30 days' WHERE id = '${p.user_id}';`);
      console.log();
    }
  }
}

listPendingPayments();
