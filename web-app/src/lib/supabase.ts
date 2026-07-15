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

export async function fetchProfilesInBatches(
  userIds: string[],
  selectFields: string = 'id, full_name, phone_number, is_premium, skills',
  chunkSize: number = 100
) {
  if (!userIds || userIds.length === 0) return { data: [], error: null };
  
  const allProfiles: any[] = [];
  
  for (let i = 0; i < userIds.length; i += chunkSize) {
    const chunk = userIds.slice(i, i + chunkSize);
    const { data, error } = await supabase
      .from('profiles')
      .select(selectFields)
      .in('id', chunk);
      
    if (error) {
      return { data: null, error };
    }
    if (data) {
      allProfiles.push(...data);
    }
  }
  
  return { data: allProfiles, error: null };
}
