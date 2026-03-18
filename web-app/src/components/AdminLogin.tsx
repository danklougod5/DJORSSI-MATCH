import React, { useState } from 'react';
import { supabase } from '../lib/supabase';
import { Lock, Mail, ArrowRight, ShieldCheck } from 'lucide-react';

interface AdminLoginProps {
  onLoginSuccess: () => void;
  onBack: () => void;
}

const AdminLogin: React.FC<AdminLoginProps> = ({ onLoginSuccess, onBack }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [initLoading, setInitLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  
  // Timeout helper for auth calls
  const timeout = (ms: number) => new Promise((_, reject) => 
    setTimeout(() => reject(new Error('Le serveur ne répond pas (Timeout)')), ms)
  );

  const initAdmin = async () => {
    setInitLoading(true);
    setError(null);
    setSuccess(null);
    try {
      // 1. Try to sign up
      const { data, error: signUpError } = await supabase.auth.signUp({
        email: 'admin@djossimatch.ci',
        password: 'Djorssi2026!',
      });

      let userId = data.user?.id;

      // 2. If already exists, we need the ID
      if (signUpError && signUpError.message.includes('already registered')) {
        const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
          email: 'admin@djossimatch.ci',
          password: 'Djorssi2026!',
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

      setSuccess("Accès Admin configuré ! Connectez-vous avec admin@djossimatch.ci / Djorssi2026!");
    } catch (err: any) {
      setError(err.message || "Erreur d'initialisation");
    } finally {
      setInitLoading(false);
    }
  };


  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const { data, error: loginError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (loginError) throw loginError;

      // Optional: Check if the user has an admin role in your profiles table
      const { data: profile } = await supabase
        .from('profiles')
        .select('is_admin')
        .eq('id', data.user.id)
        .single();

      if (profile && profile.is_admin) {
        // Redirection immédiate si le profil est Admin
        onLoginSuccess();
      } else {
        // If not admin, sign them out immediately
        await supabase.auth.signOut();
        throw new Error("Accès refusé : Vous n'êtes pas administrateur.");
      }

    } catch (err: any) {
      setError(err.message || "Erreur lors de la connexion");
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
                  placeholder="admin@djossimatch.ci"
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
