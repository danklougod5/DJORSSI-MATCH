import { createClient } from '@supabase/supabase-js'
import dotenv from 'dotenv'

dotenv.config({ path: './.env' })

const supabaseUrl = process.env.VITE_SUPABASE_URL
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY

const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function testInsert() {
  console.log("Attempting insert...")
  const { data, error } = await supabase.from('ios_waitlist').insert([{ email: 'test_js_' + Date.now() + '@djorssi.com' }])
  console.log("Data:", data)
  console.log("Error:", error)
}

testInsert()
