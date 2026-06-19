import React, { useState, useEffect } from 'react';
import { Megaphone, Trash2, CheckCircle2, AlertCircle, Plus, Eye, Sparkles } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Announcement {
  id: string;
  title: string;
  message: string;
  type: 'discount' | 'update' | 'info';
  is_active: boolean;
  cta_label: string | null;
  cta_url: string | null;
  created_at: string;
}

const AnnouncementsTab: React.FC = () => {
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [type, setType] = useState<'discount' | 'update' | 'info'>('discount');
  const [ctaLabel, setCtaLabel] = useState('');
  const [ctaUrl, setCtaUrl] = useState('');
  const [isActive, setIsActive] = useState(true);
  
  const [isLoading, setIsLoading] = useState(false);
  const [isFetching, setIsFetching] = useState(true);
  const [success, setSuccess] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    fetchAnnouncements();
  }, []);

  const fetchAnnouncements = async () => {
    setIsFetching(true);
    try {
      // Fetch all announcements (ordered by created_at descending)
      const { data, error } = await supabase
        .from('app_announcements')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setAnnouncements(data || []);
    } catch (err: any) {
      console.error('Error fetching announcements:', err);
      setError('Impossible de charger les annonces: ' + err.message);
    } finally {
      setIsFetching(false);
    }
  };

  const handleCreateAnnouncement = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !message) {
      setError('Veuillez remplir le titre et le message.');
      return;
    }

    setIsLoading(true);
    setError('');
    setSuccess('');

    try {
      const { error: insertError } = await supabase
        .from('app_announcements')
        .insert([
          {
            title,
            message,
            type,
            is_active: isActive,
            cta_label: ctaLabel.trim() || null,
            cta_url: ctaUrl.trim() || null,
          }
        ]);

      if (insertError) throw insertError;

      setSuccess('Annonce créée avec succès !');
      setTitle('');
      setMessage('');
      setCtaLabel('');
      setCtaUrl('');
      setIsActive(true);
      fetchAnnouncements();
    } catch (err: any) {
      console.error('Error creating announcement:', err);
      setError('Erreur lors de la création : ' + err.message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggleActive = async (id: string, currentStatus: boolean) => {
    setError('');
    setSuccess('');
    
    // Update local state first (optimistic UI update)
    setAnnouncements(prev =>
      prev.map(a => (a.id === id ? { ...a, is_active: !currentStatus } : a))
    );

    try {
      const { error: updateError } = await supabase
        .from('app_announcements')
        .update({ is_active: !currentStatus })
        .eq('id', id);

      if (updateError) {
        // Revert local state on error
        setAnnouncements(prev =>
          prev.map(a => (a.id === id ? { ...a, is_active: currentStatus } : a))
        );
        throw updateError;
      }
      setSuccess('Statut de l\'annonce mis à jour.');
    } catch (err: any) {
      console.error('Error toggling status:', err);
      setError('Erreur de mise à jour: ' + err.message);
      fetchAnnouncements();
    }
  };

  const handleDeleteAnnouncement = async (id: string) => {
    if (!window.confirm('Voulez-vous vraiment supprimer cette annonce ?')) return;

    setError('');
    setSuccess('');

    try {
      const { error: deleteError } = await supabase
        .from('app_announcements')
        .delete()
        .eq('id', id);

      if (deleteError) throw deleteError;

      setSuccess('Annonce supprimée.');
      setAnnouncements(prev => prev.filter(a => a.id !== id));
    } catch (err: any) {
      console.error('Error deleting announcement:', err);
      setError('Erreur lors de la suppression: ' + err.message);
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      
      {/* Messages de retour */}
      {(success || error) && (
        <div className="space-y-2">
          {success && (
            <div className="p-4 bg-green-50 border-2 border-green-500/20 text-green-700 rounded-2xl flex items-center gap-3 font-bold text-sm">
              <CheckCircle2 size={20} className="text-green-500" />
              {success}
            </div>
          )}
          {error && (
            <div className="p-4 bg-red-50 border-2 border-red-500/20 text-red-700 rounded-2xl flex items-center gap-3 font-bold text-sm">
              <AlertCircle size={20} className="text-red-500" />
              {error}
            </div>
          )}
        </div>
      )}

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
        
        {/* Formulaire de création */}
        <div className="xl:col-span-2 bg-white p-8 rounded-3xl border border-slate-200 shadow-sm space-y-6">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-primary/10 rounded-2xl flex items-center justify-center text-primary">
              <Megaphone size={24} />
            </div>
            <div>
              <h3 className="text-xl font-black uppercase tracking-tighter">Créer une Annonce</h3>
              <p className="text-slate-500 text-sm font-medium">Diffusez un pop-up d'alerte lors de la connexion des candidats.</p>
            </div>
          </div>

          <form onSubmit={handleCreateAnnouncement} className="space-y-5">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <label className="text-sm font-bold text-slate-700 uppercase tracking-wider ml-1">Type d'Annonce</label>
                <select
                  value={type}
                  onChange={(e) => setType(e.target.value as any)}
                  className="w-full p-4 rounded-2xl border-2 border-slate-100 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all font-bold outline-none bg-slate-50/50"
                >
                  <option value="discount">🏷️ Réduction / Offre</option>
                  <option value="update">🚀 Mise à jour Disponible</option>
                  <option value="info">📢 Information Générale</option>
                </select>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-bold text-slate-700 uppercase tracking-wider ml-1">Statut Initial</label>
                <div className="flex gap-4">
                  <button
                    type="button"
                    onClick={() => setIsActive(true)}
                    className={`flex-1 p-4 rounded-2xl border-2 transition-all font-bold ${
                      isActive 
                        ? 'border-primary bg-primary/5 text-primary shadow-sm' 
                        : 'border-slate-100 bg-slate-50 text-slate-500 hover:border-slate-200'
                    }`}
                  >
                    Actif Direct
                  </button>
                  <button
                    type="button"
                    onClick={() => setIsActive(false)}
                    className={`flex-1 p-4 rounded-2xl border-2 transition-all font-bold ${
                      !isActive 
                        ? 'border-slate-950 bg-slate-900 text-white shadow-sm' 
                        : 'border-slate-100 bg-slate-50 text-slate-500 hover:border-slate-200'
                    }`}
                  >
                    Brouillon
                  </button>
                </div>
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-bold text-slate-700 uppercase tracking-wider ml-1">Titre de l'Annonce</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Ex: -50% sur l'accès Premium aujourd'hui ! 🎁"
                className="w-full p-4 rounded-2xl border-2 border-slate-100 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all font-medium outline-none bg-slate-50/50"
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-bold text-slate-700 uppercase tracking-wider ml-1">Message principal</label>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="Ex: Profitez d'une offre exceptionnelle pour booster vos candidatures avec des exports de CV illimités..."
                rows={3}
                className="w-full p-4 rounded-2xl border-2 border-slate-100 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all font-medium outline-none bg-slate-50/50 resize-none"
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <label className="text-sm font-bold text-slate-700 uppercase tracking-wider ml-1">Texte du bouton CTA (Optionnel)</label>
                <input
                  type="text"
                  value={ctaLabel}
                  onChange={(e) => setCtaLabel(e.target.value)}
                  placeholder="Ex: Découvrir l'offre"
                  className="w-full p-4 rounded-2xl border-2 border-slate-100 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all font-medium outline-none bg-slate-50/50"
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm font-bold text-slate-700 uppercase tracking-wider ml-1">Lien du CTA (Optionnel)</label>
                <input
                  type="text"
                  value={ctaUrl}
                  onChange={(e) => setCtaUrl(e.target.value)}
                  placeholder="Ex: /premium ou https://store.com"
                  className="w-full p-4 rounded-2xl border-2 border-slate-100 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all font-medium outline-none bg-slate-50/50"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="w-full bg-slate-900 text-white p-5 rounded-2xl font-black uppercase tracking-widest flex items-center justify-center gap-3 hover:bg-primary hover:shadow-xl hover:shadow-primary/30 transition-all disabled:opacity-50"
            >
              {isLoading ? (
                <div className="w-6 h-6 border-4 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <Plus size={20} />
                  Enregistrer l'annonce
                </>
              )}
            </button>
          </form>
        </div>

        {/* Aperçu mobile */}
        <div className="bg-slate-900 p-6 rounded-3xl flex flex-col items-center justify-center border-4 border-slate-800 shadow-2xl relative min-h-[500px] text-white">
          <div className="absolute top-4 left-4 flex items-center gap-2 text-xs font-bold tracking-widest text-slate-400 uppercase">
            <Eye size={14} /> Aperçu Mobile
          </div>

          {/* Phone Screen Container */}
          <div className="w-full max-w-[270px] aspect-[9/16] bg-slate-800/80 rounded-[2rem] border-4 border-slate-700 p-3 flex flex-col relative overflow-hidden shadow-inner">
            
            {/* Status bar */}
            <div className="flex justify-between items-center text-[10px] font-bold text-slate-400 px-2 pt-1 mb-6">
              <span>09:41</span>
              <div className="w-16 h-4 bg-black rounded-b-xl absolute top-0 left-1/2 -translate-x-1/2" />
              <span>🔋 100%</span>
            </div>

            {/* Fake offers view */}
            <div className="flex-1 flex flex-col justify-center items-center opacity-30 pointer-events-none scale-90">
              <div className="w-full bg-white rounded-2xl p-4 space-y-3">
                <div className="h-4 bg-slate-300 w-2/3 rounded" />
                <div className="h-3 bg-slate-200 w-1/2 rounded" />
                <div className="h-20 bg-slate-100 rounded" />
              </div>
            </div>

            {/* In-app Popup Dialog Simulation */}
            <div className="absolute inset-0 bg-black/60 backdrop-blur-[2px] flex items-center justify-center p-3 animate-in fade-in duration-300">
              <div className="bg-slate-900 border border-slate-800 w-full rounded-2xl shadow-2xl overflow-hidden flex flex-col">
                
                {/* Header background gradient based on type */}
                <div className={`p-4 text-center relative overflow-hidden flex flex-col items-center justify-center ${
                  type === 'discount' 
                    ? 'bg-gradient-to-r from-amber-500 via-yellow-500 to-rose-500' 
                    : type === 'update'
                    ? 'bg-gradient-to-r from-violet-600 via-indigo-600 to-blue-600'
                    : 'bg-gradient-to-r from-slate-700 to-slate-800'
                }`}>
                  <div className="absolute inset-0 opacity-10 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-white via-transparent to-transparent animate-pulse" />
                  
                  {type === 'discount' && <Sparkles size={28} className="text-white animate-bounce mb-1" />}
                  {type === 'update' && <Sparkles size={28} className="text-white animate-pulse mb-1" />}
                  {type === 'info' && <Megaphone size={28} className="text-white mb-1" />}

                  <h4 className="font-extrabold text-sm text-white tracking-tight text-center leading-tight">
                    {title || 'Titre de l\'annonce'}
                  </h4>
                </div>

                {/* Content */}
                <div className="p-4 space-y-4 bg-slate-950 flex-1 flex flex-col">
                  <p className="text-[11px] text-slate-300 leading-relaxed text-center font-medium overflow-y-auto max-h-[100px]">
                    {message || 'Le message décrivant les détails de l\'offre ou de la mise à jour s\'affichera ici.'}
                  </p>

                  <div className="space-y-2 mt-auto">
                    {ctaLabel && (
                      <button className={`w-full py-2.5 rounded-xl font-black text-[11px] uppercase tracking-wider transition-transform active:scale-95 ${
                        type === 'discount' 
                          ? 'bg-gradient-to-r from-amber-400 to-rose-500 text-white' 
                          : type === 'update'
                          ? 'bg-gradient-to-r from-violet-500 to-blue-600 text-white'
                          : 'bg-white text-slate-950'
                      }`}>
                        {ctaLabel}
                      </button>
                    )}

                    <button className="w-full py-2 bg-slate-900 border border-slate-800 text-[10px] text-slate-400 font-bold uppercase tracking-widest rounded-xl">
                      Fermer
                    </button>
                  </div>
                </div>
              </div>
            </div>

          </div>
        </div>

      </div>

      {/* Liste des annonces existantes */}
      <div className="bg-white p-8 rounded-3xl border border-slate-200 shadow-sm space-y-6">
        <h3 className="text-xl font-black uppercase tracking-tighter flex items-center gap-2">
          Annonces de la Base
          <span className="bg-slate-100 text-slate-600 text-xs px-2.5 py-1 rounded-full font-bold">
            {announcements.length}
          </span>
        </h3>

        {isFetching ? (
          <div className="flex justify-center items-center py-12">
            <div className="w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : announcements.length === 0 ? (
          <div className="text-center py-12 text-slate-400 font-bold uppercase text-xs tracking-wider border-2 border-dashed border-slate-100 rounded-3xl">
            Aucune annonce trouvée dans la base.
          </div>
        ) : (
          <div className="overflow-x-auto rounded-2xl border border-slate-100">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-100 font-bold text-slate-400 text-[11px] uppercase tracking-widest">
                  <th className="p-5">Type</th>
                  <th className="p-5">Titre / Message</th>
                  <th className="p-5">Lien / Route</th>
                  <th className="p-5 text-center">Statut</th>
                  <th className="p-5 text-center">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 font-medium text-sm">
                {announcements.map((a) => (
                  <tr key={a.id} className="hover:bg-slate-50/50 transition-colors">
                    <td className="p-5">
                      {a.type === 'discount' && (
                        <span className="bg-amber-100 text-amber-800 text-xs px-2.5 py-1 rounded-full font-bold uppercase tracking-wider border border-amber-200">
                          🏷️ Réduction
                        </span>
                      )}
                      {a.type === 'update' && (
                        <span className="bg-violet-100 text-violet-800 text-xs px-2.5 py-1 rounded-full font-bold uppercase tracking-wider border border-violet-200">
                          🚀 Màj
                        </span>
                      )}
                      {a.type === 'info' && (
                        <span className="bg-slate-100 text-slate-800 text-xs px-2.5 py-1 rounded-full font-bold uppercase tracking-wider border border-slate-200">
                          📢 Info
                        </span>
                      )}
                    </td>
                    <td className="p-5 max-w-sm">
                      <div className="font-extrabold text-slate-900 leading-tight">{a.title}</div>
                      <div className="text-slate-500 text-xs font-medium mt-1 leading-normal line-clamp-2">{a.message}</div>
                    </td>
                    <td className="p-5 text-slate-600 font-semibold text-xs">
                      {a.cta_label ? (
                        <div className="space-y-1">
                          <span className="bg-slate-100 text-slate-700 px-2 py-0.5 rounded font-black text-[9px] uppercase tracking-wider mr-2">{a.cta_label}</span>
                          <code className="text-slate-400 font-medium">{a.cta_url || '-'}</code>
                        </div>
                      ) : (
                        <span className="text-slate-300 font-normal">Sans action</span>
                      )}
                    </td>
                    <td className="p-5 text-center">
                      <button
                        onClick={() => handleToggleActive(a.id, a.is_active)}
                        className={`px-4 py-2.5 rounded-full text-xs font-extrabold transition-all border ${
                          a.is_active 
                            ? 'bg-emerald-50 border-emerald-300 text-emerald-700 shadow-sm shadow-emerald-100 hover:bg-emerald-100' 
                            : 'bg-slate-100 border-slate-200 text-slate-400 hover:bg-slate-200/50'
                        }`}
                      >
                        {a.is_active ? 'Actif' : 'Brouillon'}
                      </button>
                    </td>
                    <td className="p-5 text-center">
                      <button
                        onClick={() => handleDeleteAnnouncement(a.id)}
                        className="p-3 bg-red-50 text-red-500 hover:bg-red-500 hover:text-white rounded-xl transition-all shadow-sm shadow-red-50"
                      >
                        <Trash2 size={16} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

    </div>
  );
};

export default AnnouncementsTab;
