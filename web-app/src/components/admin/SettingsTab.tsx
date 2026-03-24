import React from 'react';
import { Lock, AlertCircle, CheckCircle2, RefreshCw, LogOut } from 'lucide-react';

interface SettingsTabProps {
  handleUpdatePassword: (e: React.FormEvent<HTMLFormElement>) => Promise<void>;
  passwordError: string;
  passwordSuccess: string;
  isLoading: boolean;
  onLogout: () => void;
}

const SettingsTab: React.FC<SettingsTabProps> = ({
  handleUpdatePassword,
  passwordError,
  passwordSuccess,
  isLoading,
  onLogout
}) => {
  return (
    <div className="max-w-2xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="bg-white p-6 md:p-8 rounded-2xl border border-slate-200 shadow-sm">
        <h2 className="text-xl font-heading mb-6 flex items-center gap-2 text-slate-900 border-b pb-4">
          <Lock className="text-primary" size={24} /> Sécurité du Compte
        </h2>
        <p className="text-sm text-slate-500 mb-6">
          Mettez à jour votre mot de passe pour garantir la sécurité de votre accès administrateur.
        </p>
        
        <form onSubmit={handleUpdatePassword} className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-sm font-semibold text-slate-700">Nouveau mot de passe</label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                <input 
                  type="password" 
                  name="newPassword"
                  required
                  placeholder="••••••••"
                  className="w-full pl-10 pr-4 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all placeholder:text-slate-300"
                  minLength={6}
                />
              </div>
            </div>
            
            <div className="space-y-2">
              <label className="text-sm font-semibold text-slate-700">Confirmer le mot de passe</label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                <input 
                  type="password" 
                  name="confirmPassword"
                  required
                  placeholder="••••••••"
                  className="w-full pl-10 pr-4 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all placeholder:text-slate-300"
                  minLength={6}
                />
              </div>
            </div>
          </div>

          <div className="pt-2">
            {passwordError && (
              <div className="bg-red-50 text-red-600 px-4 py-3 rounded-xl flex items-center gap-2 mb-4 text-sm animate-in shake duration-300">
                <AlertCircle size={16} /> {passwordError}
              </div>
            )}
            {passwordSuccess && (
             <div className="bg-green-50 text-green-600 px-4 py-3 rounded-xl flex items-center gap-2 mb-4 text-sm animate-in zoom-in duration-300">
                <CheckCircle2 size={16} /> {passwordSuccess}
              </div>
            )}

            <button 
              type="submit"
              disabled={isLoading}
              className="w-full bg-primary text-white py-3 rounded-xl font-bold hover:shadow-lg hover:shadow-primary/20 active:scale-95 transition-all disabled:opacity-50 disabled:active:scale-100 flex items-center justify-center gap-2"
            >
              {isLoading ? (
                <>
                  <RefreshCw className="animate-spin" size={18} />
                  Mise à jour...
                </>
              ) : (
                'Sauvegarder le nouveau mot de passe'
              )}
            </button>
          </div>
        </form>
      </div>

      <div className="bg-slate-50 p-6 rounded-2xl border border-dashed border-slate-200">
        <h3 className="text-sm font-bold text-slate-900 mb-2">Informations de session</h3>
        <p className="text-xs text-slate-500 mb-4">
          Si vous rencontrez des problèmes de déconnexion automatique, essayez de vous déconnecter manuellement puis de vous reconnecter.
        </p>
        <button 
          type="button"
          onClick={onLogout}
          className="text-xs font-bold text-red-500 hover:text-red-600 flex items-center gap-1"
        >
          <LogOut size={14} /> Se déconnecter maintenant
        </button>
      </div>
    </div>
  );
};

export default SettingsTab;
