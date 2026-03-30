import { useState, useEffect } from 'react'
import { Routes, Route, Navigate, useNavigate } from 'react-router-dom'
import LandingPage from './components/LandingPage'
import AdminDashboard from './components/AdminDashboard'
import AdminLogin from './components/AdminLogin'
import { supabase } from './lib/supabase'
import { TermsOfService, PrivacyPolicy } from './components/LegalPages'

function App() {
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null)
  const [isInitializing, setIsInitializing] = useState(true)
  const navigate = useNavigate()

  useEffect(() => {
    // Sécurité : s'assurer que l'app s'affiche quoi qu'il arrive après 4s
    const safetyTimer = setTimeout(() => {
      setIsInitializing(false);
    }, 4000);

    const checkSession = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (session) {
          const { data: profile } = await supabase
            .from('profiles')
            .select('is_admin')
            .eq('id', session.user.id)
            .single()
          
          setIsAdmin(!!profile?.is_admin)
        } else {
          setIsAdmin(false)
        }
      } catch (error) {
        console.warn('Initial session check error:', error);
        setIsAdmin(false)
      } finally {
        setIsInitializing(false)
      }
    }

    checkSession()

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      try {
        if (event === 'SIGNED_IN' && session) {
          // On ne remet PLUS isInitializing à true ici pour éviter de bloquer l'écran
          const { data: profile } = await supabase
            .from('profiles')
            .select('is_admin')
            .eq('id', session.user.id)
            .single()
          
          setIsAdmin(!!profile?.is_admin)
        } else if (event === 'SIGNED_OUT') {
          setIsAdmin(false)
          if (window.location.pathname.startsWith('/admin')) {
            navigate('/admin')
          }
        }
      } catch (e) {
        console.error("Auth change error handled:", e)
        setIsAdmin(false)
      } finally {
        // Au cas où c'est le SIGNED_IN initial qui déclenche onAuthStateChange
        setIsInitializing(false)
      }
    })

    return () => {
      clearTimeout(safetyTimer);
      subscription.unsubscribe();
    }
  }, [navigate])

  const handleLogout = async () => {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      console.error('Error during signOut:', e);
    } finally {
      setIsAdmin(false);
      navigate('/admin');
    }
  };

  if (isInitializing) {
    return (
      <div className="min-h-screen bg-slate-50 flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
          <p className="font-black text-slate-400 uppercase tracking-widest text-[10px]">Chargement sécurisé...</p>
        </div>
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

        <Route path="/terms" element={<TermsOfService />} />
        <Route path="/privacy" element={<PrivacyPolicy />} />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </div>
  )
}

export default App
