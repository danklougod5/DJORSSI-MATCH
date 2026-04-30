import React, { useState } from 'react';
import { Send, Bell, Smartphone, Users, Star, AlertCircle, CheckCircle2 } from 'lucide-react';
import { supabase } from '../../lib/supabase';

const NotificationsTab: React.FC = () => {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [target, setTarget] = useState<'all' | 'premium'>('all');
  const [isLoading, setIsLoading] = useState(false);
  const [success, setSuccess] = useState('');
  const [error, setError] = useState('');

  const handleSendNotification = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !message) {
      setError('Veuillez remplir le titre et le message.');
      return;
    }

    setIsLoading(true);
    setError('');
    setSuccess('');

    try {
      // On appelle la Edge Function Supabase (qu'on va créer plus tard)
      const { data, error: funcError } = await supabase.functions.invoke('send-broadcast-notification', {
        body: { 
          title, 
          message, 
          target 
        }
      });

      if (funcError) throw funcError;

      setSuccess('Notification envoyée avec succès à tous les utilisateurs !');
      setTitle('');
      setMessage('');
    } catch (err: any) {
      console.error('Erreur notification:', err);
      setError('Erreur lors de l\'envoi : ' + (err.message || 'La fonction n\'est peut-être pas encore déployée.'));
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        
        {/* Formulaire de configuration */}
        <div className="bg-white p-8 rounded-3xl border border-slate-200 shadow-sm">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-12 h-12 bg-primary/10 rounded-2xl flex items-center justify-center text-primary">
              <Bell size={24} />
            </div>
            <div>
              <h3 className="text-xl font-black uppercase tracking-tighter">Nouvelle Campagne</h3>
              <p className="text-slate-500 text-sm font-medium">Envoyez un message direct à vos utilisateurs.</p>
            </div>
          </div>

          <form onSubmit={handleSendNotification} className="space-y-6">
            <div className="space-y-2">
              <label className="text-sm font-bold text-slate-700 uppercase tracking-wider ml-1">Cible de l'envoi</label>
              <div className="grid grid-cols-2 gap-4">
                <button
                  type="button"
                  onClick={() => setTarget('all')}
                  className={`flex items-center justify-center gap-3 p-4 rounded-2xl border-2 transition-all font-bold ${
                    target === 'all' 
                      ? 'border-primary bg-primary/5 text-primary shadow-sm' 
                      : 'border-slate-100 bg-slate-50 text-slate-500 hover:border-slate-200'
                  }`}
                >
                  <Users size={20} />
                  Tous les utilisateurs
                </button>
                <button
                  type="button"
                  onClick={() => setTarget('premium')}
                  className={`flex items-center justify-center gap-3 p-4 rounded-2xl border-2 transition-all font-bold ${
                    target === 'premium' 
                      ? 'border-amber-500 bg-amber-50 text-amber-700 shadow-sm' 
                      : 'border-slate-100 bg-slate-50 text-slate-500 hover:border-slate-200'
                  }`}
                >
                  <Star size={20} />
                  Membres Premium
                </button>
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-bold text-slate-700 uppercase tracking-wider ml-1">Titre de la notification</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Ex: 🎁 Cadeau Fête du Travail !"
                className="w-full p-4 rounded-2xl border-2 border-slate-100 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all font-medium outline-none bg-slate-50/50"
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-bold text-slate-700 uppercase tracking-wider ml-1">Contenu du message</label>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="Ex: Profitez de l'accès Premium gratuit aujourd'hui sur Djorssi Match..."
                rows={4}
                className="w-full p-4 rounded-2xl border-2 border-slate-100 focus:border-primary focus:ring-4 focus:ring-primary/10 transition-all font-medium outline-none bg-slate-50/50 resize-none"
              />
            </div>

            {error && (
              <div className="p-4 bg-red-50 border border-red-100 text-red-600 rounded-2xl flex items-center gap-3 font-bold text-sm animate-in shake duration-300">
                <AlertCircle size={20} />
                {error}
              </div>
            )}

            {success && (
              <div className="p-4 bg-green-50 border border-green-100 text-green-600 rounded-2xl flex items-center gap-3 font-bold text-sm animate-in zoom-in duration-300">
                <CheckCircle2 size={20} />
                {success}
              </div>
            )}

            <button
              type="submit"
              disabled={isLoading}
              className="w-full bg-slate-900 text-white p-5 rounded-2xl font-black uppercase tracking-widest flex items-center justify-center gap-3 hover:bg-primary hover:shadow-xl hover:shadow-primary/30 transition-all disabled:opacity-50 disabled:hover:bg-slate-900 group"
            >
              {isLoading ? (
                <div className="w-6 h-6 border-4 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  Envoyer la notification
                  <Send size={20} className="group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
                </>
              )}
            </button>
          </form>
        </div>

        {/* Aperçu en temps réel */}
        <div className="flex flex-col items-center justify-center space-y-6">
          <div className="relative w-[300px] h-[600px] bg-slate-900 rounded-[3rem] border-[8px] border-slate-800 shadow-2xl p-4 overflow-hidden">
            {/* Speaker/Camera bar */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-7 bg-slate-800 rounded-b-2xl z-10" />
            
            {/* Screen content */}
            <div className="h-full w-full rounded-[2rem] bg-slate-200 relative p-4 flex flex-col pt-12">
              <div className="text-slate-400 font-bold text-xs mb-8 text-center uppercase tracking-widest">Aperçu Téléphone</div>
              
              {/* Notification Bubble */}
              {(title || message) && (
                <div className="w-full bg-white/90 backdrop-blur-md p-4 rounded-3xl shadow-xl border border-white animate-in slide-in-from-top-8 duration-500 flex gap-3">
                  <div className="w-10 h-10 bg-primary rounded-xl flex-shrink-0 flex items-center justify-center text-white font-black text-lg">D</div>
                  <div className="overflow-hidden">
                    <div className="flex items-center justify-between">
                      <span className="font-black text-sm truncate">{title || 'Titre de la notif'}</span>
                      <span className="text-[10px] text-slate-400 font-bold">Maintenant</span>
                    </div>
                    <p className="text-xs text-slate-600 font-medium leading-relaxed mt-1 line-clamp-3">
                      {message || 'Le contenu de votre message s\'affichera ici.'}
                    </p>
                  </div>
                </div>
              )}

              <div className="mt-auto mb-4 flex justify-center">
                <div className="w-32 h-1.5 bg-slate-400/50 rounded-full" />
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2 text-slate-400 font-bold text-sm uppercase tracking-wider">
            <Smartphone size={16} />
            Rendu temps réel
          </div>
        </div>

      </div>
    </div>
  );
};

export default NotificationsTab;
