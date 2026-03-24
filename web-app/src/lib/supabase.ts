import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase environment variables')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: false, // On désactive pour tester si c'est le storage qui bloque
    autoRefreshToken: false,
    detectSessionInUrl: false
  },
  global: {
    headers: { 'x-application-name': 'djorssi-match' }
  }
})
