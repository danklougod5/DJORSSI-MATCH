import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase environment variables')
}

let _supabase: any;

if (!(globalThis as any).__supabaseClient) {
  (globalThis as any).__supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      storageKey: 'djorssi-admin-v2-auth',
      persistSession: true
    },
    global: {
      headers: { 'x-application-name': 'djorssi-match' }
    }
  });
}

_supabase = (globalThis as any).__supabaseClient;
export const supabase = _supabase;
