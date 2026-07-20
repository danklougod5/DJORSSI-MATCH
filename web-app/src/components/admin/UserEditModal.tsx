import React from 'react';
import { X, Star, Lock, FileText, Minus, Plus } from 'lucide-react';

interface UserEditModalProps {
  editingUser: any;
  setEditingUser: (user: any) => void;
  isLoading: boolean;
  isResettingPassword: boolean;
  handleUpdateUserProfile: (e: React.FormEvent) => Promise<void>;
  handleSendPasswordReset: () => Promise<void>;
}

const UserEditModal: React.FC<UserEditModalProps> = ({
  editingUser,
  setEditingUser,
  isLoading,
  isResettingPassword,
  handleUpdateUserProfile,
  handleSendPasswordReset
}) => {
  if (!editingUser) return null;

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl w-full max-w-lg shadow-2xl border border-white/20 overflow-hidden animate-in fade-in zoom-in duration-200">
        <div className="p-6 border-b border-slate-100 flex justify-between items-center bg-slate-50/50">
          <div>
            <h3 className="text-xl font-bold text-slate-900">Modifier l'utilisateur</h3>
            <p className="text-xs text-slate-500 font-mono uppercase tracking-widest mt-1">ID: #{editingUser.id.substring(0, 8)}</p>
          </div>
          <button 
            onClick={() => setEditingUser(null)}
            className="p-2 hover:bg-white rounded-full transition-colors text-slate-400 hover:text-slate-900 shadow-sm border border-transparent hover:border-slate-200"
          >
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleUpdateUserProfile} className="p-8 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400">Nom Complet</label>
              <input 
                type="text"
                value={editingUser.name}
                onChange={(e) => setEditingUser({...editingUser, name: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 font-semibold"
                required
              />
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400">Numéro de Téléphone</label>
              <input 
                type="text"
                value={editingUser.phone}
                onChange={(e) => setEditingUser({...editingUser, phone: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 font-semibold"
              />
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black uppercase tracking-widest text-slate-400">Secteurs / Compétences (séparés par virgule)</label>
            <input 
              type="text"
              value={editingUser.sector}
              onChange={(e) => setEditingUser({...editingUser, sector: e.target.value})}
              className="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 font-semibold"
              placeholder="Ex: Informatique, Marketing, RH"
            />
          </div>

          <div className="flex items-center justify-between p-4 bg-slate-50 rounded-2xl border border-slate-200">
            <div className="flex items-center gap-3">
              <div className={`p-2 rounded-lg ${editingUser.premium ? 'bg-cta/10 text-cta' : 'bg-slate-200 text-slate-400'}`}>
                <Star size={18} fill={editingUser.premium ? "currentColor" : "none"} />
              </div>
              <div>
                <p className="text-sm font-bold text-slate-800">Status Premium</p>
                <p className="text-[10px] text-slate-500 font-medium">Contrôlez l'accès premium</p>
              </div>
            </div>
            <button 
              type="button"
              onClick={() => {
                const newPremium = !editingUser.premium;
                const defaultUntil = newPremium ? new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString() : null;
                setEditingUser({
                  ...editingUser,
                  premium: newPremium,
                  premiumUntil: defaultUntil
                });
              }}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none ${editingUser.premium ? 'bg-cta' : 'bg-slate-300'}`}
            >
              <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${editingUser.premium ? 'translate-x-6' : 'translate-x-1'}`} />
            </button>
          </div>

          {editingUser.premium && (
            <div className="space-y-2 p-4 bg-amber-50/50 border border-amber-100 rounded-2xl animate-in fade-in slide-in-from-top-2 duration-200">
              <label className="text-[10px] font-black uppercase tracking-widest text-amber-700">Date d'expiration Premium</label>
              <input 
                type="datetime-local"
                value={editingUser.premiumUntil ? new Date(editingUser.premiumUntil).toISOString().slice(0, 16) : ''}
                onChange={(e) => {
                  const val = e.target.value;
                  setEditingUser({
                    ...editingUser, 
                    premiumUntil: val ? new Date(val).toISOString() : null
                  });
                }}
                className="w-full px-4 py-3 bg-white border border-amber-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/20 font-semibold"
              />
              <p className="text-[10px] text-amber-600 mt-1">Laissez vide pour un accès Premium permanent (sans date de fin).</p>
            </div>
          )}

          <div className="flex items-center justify-between p-4 bg-slate-50 rounded-2xl border border-slate-200">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-primary/10 text-primary">
                <FileText size={18} />
              </div>
              <div>
                <p className="text-sm font-bold text-slate-800">Quota CV Supplémentaires</p>
                <p className="text-[10px] text-slate-500 font-medium">CV additionnels achetés ou offerts</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <button 
                type="button"
                onClick={() => setEditingUser({
                  ...editingUser, 
                  extraCvsPurchased: Math.max(0, (editingUser.extraCvsPurchased || 0) - 1)
                })}
                className="p-1.5 hover:bg-slate-200 rounded-lg transition-colors text-slate-600 border border-slate-200 bg-white cursor-pointer"
              >
                <Minus size={14} />
              </button>
              <span className="w-8 text-center font-mono font-bold text-slate-800 text-sm">
                {editingUser.extraCvsPurchased || 0}
              </span>
              <button 
                type="button"
                onClick={() => setEditingUser({
                  ...editingUser, 
                  extraCvsPurchased: (editingUser.extraCvsPurchased || 0) + 1
                })}
                className="p-1.5 hover:bg-slate-200 rounded-lg transition-colors text-slate-600 border border-slate-200 bg-white cursor-pointer"
              >
                <Plus size={14} />
              </button>
            </div>
          </div>

          <div className="flex items-center justify-between p-4 bg-slate-50 rounded-2xl border border-slate-200">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-lg bg-green-500/10 text-green-600">
                <Star size={18} />
              </div>
              <div>
                <p className="text-sm font-bold text-slate-800">Adaptations IA Supplémentaires</p>
                <p className="text-[10px] text-slate-500 font-medium">Adaptations IA additionnelles offertes</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <button 
                type="button"
                onClick={() => setEditingUser({
                  ...editingUser, 
                  aiAdaptExtraPurchased: Math.max(0, (editingUser.aiAdaptExtraPurchased || 0) - 1)
                })}
                className="p-1.5 hover:bg-slate-200 rounded-lg transition-colors text-slate-600 border border-slate-200 bg-white cursor-pointer"
              >
                <Minus size={14} />
              </button>
              <span className="w-8 text-center font-mono font-bold text-slate-800 text-sm">
                {editingUser.aiAdaptExtraPurchased || 0}
              </span>
              <button 
                type="button"
                onClick={() => setEditingUser({
                  ...editingUser, 
                  aiAdaptExtraPurchased: (editingUser.aiAdaptExtraPurchased || 0) + 1
                })}
                className="p-1.5 hover:bg-slate-200 rounded-lg transition-colors text-slate-600 border border-slate-200 bg-white cursor-pointer"
              >
                <Plus size={14} />
              </button>
            </div>
          </div>


          <div className="pt-4 border-t border-slate-100 flex flex-col gap-4">
            <div className="flex gap-3">
              <button 
                type="submit"
                disabled={isLoading}
                className="flex-1 bg-black text-white px-6 py-4 rounded-2xl text-sm font-black uppercase tracking-widest hover:bg-slate-900 transition-all shadow-lg shadow-black/10 disabled:opacity-50"
              >
                {isLoading ? 'Enregistrement...' : 'Enregistrer les modifications'}
              </button>
            </div>
            
            <button 
              type="button"
              onClick={handleSendPasswordReset}
              disabled={isResettingPassword}
              className="flex items-center justify-center gap-2 text-xs font-bold text-slate-400 hover:text-primary transition-colors uppercase tracking-widest border border-slate-200 py-3 rounded-2xl hover:bg-slate-50"
            >
              <Lock size={14} />
              {isResettingPassword ? "Envoi..." : "Envoyer email de réinitialisation mdp"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default UserEditModal;
