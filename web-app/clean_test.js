import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config({ path: './.env' })

const supabaseUrl = process.env.VITE_SUPABASE_URL
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY

const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function cleanTests() {
  const email = process.env.VITE_ADMIN_DEFAULT_EMAIL
  const password = process.env.VITE_ADMIN_DEFAULT_PASSWORD
  
  await supabase.auth.signInWithPassword({ email, password })
  
  const { error } = await supabase.from('ios_waitlist').delete().like('email', '%@djorssi.com')
  console.log("Cleanup error:", error)
}

cleanTests()
