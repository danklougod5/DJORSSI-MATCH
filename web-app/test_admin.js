import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config({ path: './.env' })

const supabaseUrl = process.env.VITE_SUPABASE_URL
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY

const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function testAdmin() {
  const email = process.env.VITE_ADMIN_DEFAULT_EMAIL
  const password = process.env.VITE_ADMIN_DEFAULT_PASSWORD
  
  console.log("Logging in as", email)
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email,
    password
  })
  
  if (authError) {
    console.error("Auth error:", authError)
    return
  }
  
  console.log("Logged in!")
  
  const { data, error, count } = await supabase.from('ios_waitlist').select('*', { count: 'exact' })
  console.log("Waitlist rows:", data)
  console.log("Waitlist count:", count)
  console.log("Error:", error)
}

testAdmin()
