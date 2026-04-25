import React, { useState } from 'react';
import { supabase } from '../lib/supabase';
import { Lock, Mail, ArrowRight, ShieldCheck } from 'lucide-react';

interface AdminLoginProps {
  onLoginSuccess: () => void;
  onBack: () => void;
}

const AdminLogin: React.FC<AdminLoginProps> = ({ onBack }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [initLoading, setInitLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  

  const initAdmin = async () => {
    setInitLoading(true);
    setError(null);
    setSuccess(null);
    try {
      // Nettoyer uniquement au lieu de tout détruire
      await supabase.auth.signOut();
      
      // 1. Try to sign up
      const { data, error: signUpError } = await supabase.auth.signUp({
        email: import.meta.env.VITE_ADMIN_DEFAULT_EMAIL,
        password: import.meta.env.VITE_ADMIN_DEFAULT_PASSWORD,
      });

      let userId = data.user?.id;

      // 2. If already exists, we need the ID
      if (signUpError && signUpError.message.includes('already registered')) {
        const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
          email: import.meta.env.VITE_ADMIN_DEFAULT_EMAIL,
          password: import.meta.env.VITE_ADMIN_DEFAULT_PASSWORD,
        });
        
        if (signInError) throw new Error("Le compte existe déjà. Vérifiez le mot de passe.");
        userId = signInData.user?.id;
      } else if (signUpError) {
        throw signUpError;
      }

      // 3. Force the Admin flag (REMOVED 'email' column)
      if (userId) {
        const { error: profileError } = await supabase
          .from('profiles')
          .upsert({ 
            id: userId, 
            is_admin: true, 
            full_name: 'Admin Principal'
          });
        
        if (profileError) throw profileError;
      }

      setSuccess("Accès Admin configuré ! Utilisez vos identifiants pour vous connecter.");
    } catch (err: any) {
      let msg = err.message || "Erreur d'initialisation";
      if (msg.toLowerCase().includes("user already registered")) {
        msg = "Cet utilisateur est déjà inscrit.";
      }
      setError(msg);
    } finally {
      setInitLoading(false);
    }
  };


  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    // Test de connectivité immédiat pour diagnostiquer
    const checkSupabase = async () => {
      try {
        const start = Date.now();
        const res = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/rest/v1/`, { 
          method: 'GET',
          headers: { 'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY }
        });
        const duration = Date.now() - start;
        console.log(`[NETWORK TEST] Supabase REST: status ${res.status}, temps ${duration}ms`);
      } catch (err: any) {
        console.error(`[NETWORK TEST] Supabase REST INJOIGNABLE:`, err.message);
      }
    };

    const authAttempt = async () => {
      console.log(`[AUTH] Tentative de connexion pour ${email.trim()}...`);
      const start = Date.now();
      try {
        const { data, error } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password: password.trim(),
        });

        const duration = Date.now() - start;
        console.log(`[AUTH] Réponse reçue en ${duration}ms`);

        if (error) {
          throw new Error(error.message);
        }

        return { user: data.user, session: data.session };
      } catch (e: any) {
        const duration = Date.now() - start;
        console.error(`[AUTH fail] Erreur après ${duration}ms:`, e.message);
        throw e;
      }
    };

    const profilePromise = async (userId: string, accessToken: string) => {
      console.log(`[PROFILE] Vérification des droits pour ${userId} (via fetch) ...`);
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
      
      const response = await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${userId}&select=is_admin`, {
        method: 'GET',
        headers: {
          'apikey': supabaseKey,
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      });
      
      if (!response.ok) {
        throw new Error('Erreur lors de la vérification du profil');
      }

      const data = await response.json();
      const profile = data[0];
      
      if (!profile?.is_admin) throw new Error("Accès refusé : Vous n'êtes pas administrateur.");
      return profile;
    };

    // Timeout dynamique (60s puis 120s puis 180s)
    const withTimeout = (promise: Promise<any>, ms: number, label: string) => {
      return Promise.race([
        promise,
        new Promise((_, reject) => setTimeout(() => reject(new Error(`Délai dépassé (${ms/1000}s) pour ${label}.`)), ms))
      ]);
    };

    // Retry helper for shaky network
    const withRetry = async <T,>(fn: (attempt: number) => Promise<T>, retries: number, label: string): Promise<T> => {
      for (let attempt = 1; attempt <= retries; attempt++) {
        try {
          return await fn(attempt);
        } catch (err: any) {
          const isTimeout = err.message?.includes('Délai dépassé');
          const isNetwork = err.message?.toLowerCase().includes('failed to fetch') || err.message?.toLowerCase().includes('network');
          console.error(`[RETRY DEBUG] Échec tentative ${attempt}/${retries} (${label}):`, err.message);
          
          if ((isTimeout || isNetwork) && attempt < retries) {
            const delay = attempt * 3000;
            console.warn(`Nouvelle tentative dans ${delay/1000}s...`);
            await new Promise(r => setTimeout(r, delay)); 
            continue;
          }
          throw err;
        }
      }
      throw new Error(`Échec final après ${retries} tentatives.`);
    };

    const translateError = (msg: string) => {
      const lowerMsg = msg.toLowerCase();
      if (lowerMsg.includes("invalid login credentials") || lowerMsg.includes("invalid login")) {
        return "Email ou mot de passe incorrect.";
      }
      if (lowerMsg.includes("failed to fetch") || lowerMsg.includes("network")) {
        return "Impossible de contacter le serveur. Votre connexion internet est-elle active ?";
      }
      if (lowerMsg.includes("délai dépassé")) {
        return "Connexion trop lente (3 minutes sans réponse). Veuillez changer de réseau ou réessayer.";
      }
      return msg;
    };

    try {
      await checkSupabase();
      
      // Tentative Auth avec timeouts progressifs (60s, 120s, 180s)
      const authData = await withRetry(
        (att) => withTimeout(authAttempt(), att === 1 ? 60000 : att === 2 ? 120000 : 180000, "l'authentification"),
        3,
        "l'authentification"
      );
      
      if (authData?.user?.id && authData?.session?.access_token) {
        // Vérification profil via fetch
        await withRetry(
          () => withTimeout(profilePromise(authData.user.id, authData.session.access_token), 45000, "la vérification du profil"),
          2,
          "la vérification du profil"
        );
        
        console.log("[LOGIN] Authentification validée !");
        onLoginSuccess();
      } else {
        throw new Error("Authentification réussie mais données manquantes.");
      }
    } catch (err: any) {
      console.error("ERREUR CRITIQUE CONNEXION:", err);
      setError(translateError(err.message || "Erreur de connexion"));
      await supabase.auth.signOut();
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="neo-brutal-card !bg-white">
          <div className="text-center mb-8">
            <div className="w-16 h-16 bg-primary border-4 border-black flex items-center justify-center mx-auto mb-4 shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] rotate-3">
              <ShieldCheck size={32} className="text-white" />
            </div>
            <h1 className="text-3xl font-black uppercase italic">ADMIN<span className="text-primary not-italic">SPACE</span></h1>
            <p className="font-bold text-slate-500 mt-2">Accès restreint au personnel autorisé</p>
          </div>

          <form onSubmit={handleLogin} className="space-y-6">
            <div>
              <label className="block text-sm font-black uppercase mb-2">Email Professionnel</label>
              <div className="relative">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <input 
                  type="email" 
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full pl-12 pr-4 py-3 border-4 border-black font-bold focus:outline-none focus:bg-accent ring-0"
                  placeholder="votre@email.com"
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-black uppercase mb-2">Mot de passe</label>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                <input 
                  type="password" 
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full pl-12 pr-4 py-3 border-4 border-black font-bold focus:outline-none focus:bg-accent ring-0"
                  placeholder="••••••••"
                  required
                />
              </div>
            </div>

            {error && (
              <div className="p-4 bg-red-100 border-2 border-red-500 text-red-600 font-bold text-sm">
                ⚠️ {error}
              </div>
            )}

            {success && (
              <div className="p-4 bg-green-100 border-2 border-green-500 text-green-600 font-bold text-sm">
                ✅ {success}
              </div>
            )}

            <button 
              type="submit"
              disabled={loading}
              className="neo-brutal-btn w-full !bg-black !text-white flex items-center justify-center gap-3 py-4 disabled:opacity-50"
            >
              {loading ? "CONNEXION..." : "SE CONNECTER"}
              {!loading && <ArrowRight size={20} />}
            </button>
          </form>

          <div className="mt-10 pt-6 border-t-4 border-dashed border-slate-100">
             <p className="text-[10px] font-black text-slate-400 uppercase mb-3 text-center tracking-widest">Zone de Maintenance</p>
             <button 
                type="button"
                onClick={initAdmin}
                disabled={initLoading}
                className="w-full py-2 border-2 border-slate-200 text-slate-400 font-bold text-[10px] hover:border-primary hover:text-primary transition-all uppercase tracking-tighter disabled:opacity-50"
             >
                {initLoading ? "INITIALISATION..." : "Initialiser Compte Admin Par Défaut"}
             </button>
          </div>

          <button 
            onClick={onBack}
            className="w-full mt-6 text-sm font-black text-slate-400 hover:text-black transition-colors uppercase tracking-wider"
          >
            ← Retour au site
          </button>
        </div>
        
        <p className="text-center mt-8 text-xs font-bold text-slate-400 uppercase tracking-widest">
          © 2026 DJORSSI-MATCH SECURITY SYSTEM
        </p>
      </div>
    </div>
  );
};

export default AdminLogin;
