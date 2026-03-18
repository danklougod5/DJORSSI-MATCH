import { useState, useEffect } from 'react'
import { Routes, Route, Navigate, useNavigate } from 'react-router-dom'
import LandingPage from './components/LandingPage'
import AdminDashboard from './components/AdminDashboard'
import AdminLogin from './components/AdminLogin'
import { supabase } from './lib/supabase'

function App() {
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null)
  const [loading, setLoading] = useState(true)
  const navigate = useNavigate()

  useEffect(() => {
    // Timeout helper - if getSession hangs (corrupted token/lock), force continue
    const timeout = (ms: number) => new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Session check timeout')), ms)
    );

    const checkSession = async () => {
      try {
        const result = await Promise.race([
          supabase.auth.getSession(),
          timeout(10000)
        ]) as any;

        const session = result?.data?.session;
        
        if (session) {
          const { data: profile } = await supabase
            .from('profiles')
            .select('is_admin')
            .eq('id', session.user.id)
            .single()
          
          if (profile?.is_admin) {
            setIsAdmin(true)
          } else {
            await supabase.auth.signOut()
            setIsAdmin(false)
          }
        } else {
          setIsAdmin(false)
        }
      } catch (error) {
        console.warn('Session check failed or timed out, clearing local cache');
        try {
          localStorage.clear();
          await supabase.auth.signOut();
        } catch (e) {
          console.error('Failed to clear session:', e);
        }
        setIsAdmin(false);
      } finally {
        setLoading(false)
      }
    }

    checkSession()

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', session.user.id)
          .single()
        
        if (profile?.is_admin) {
          setIsAdmin(true)
        } else {
          setIsAdmin(false)
        }
      } else if (event === 'SIGNED_OUT') {
        setIsAdmin(false)
        navigate('/')
      }
    })

    return () => subscription.unsubscribe()
  }, [navigate])

  const handleLogout = async () => {
    await supabase.auth.signOut()
    setIsAdmin(false)
    navigate('/')
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-primary border-t-transparent"></div>
      </div>
    )
  }

  return (
    <div className="App">
      <Routes>
        <Route path="/" element={<LandingPage />} />
        
        <Route 
          path="/admin" 
          element={
            isAdmin === true ? (
              <AdminDashboard onLogout={handleLogout} />
            ) : (
              <AdminLogin onLoginSuccess={() => setIsAdmin(true)} onBack={() => navigate('/')} />
            )
          } 
        />

        {/* Catch all redirect to home */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </div>
  )
}

export default App
