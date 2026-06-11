import React, { useEffect, useState } from 'react';
import {
  Hand,
  AlertCircle,
  CheckCircle2,
  RefreshCw,
  Eye,
  Lock,
} from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface SwipeConfig {
  swipe_limit: number;
  swipe_limit_title: string;
  swipe_limit_message: string;
}

const DEFAULT_CONFIG: SwipeConfig = {
  swipe_limit: 10,
  swipe_limit_title: 'Limite atteinte !',
  swipe_limit_message:
    "Vous avez utilisé vos {limit} swipes gratuits pour aujourd'hui.",
};

/**
 * Remplace le placeholder {limit} par la valeur configurée (comme dans l'app).
 */
const formatMessage = (message: string, limit: number): string =>
  message.replace(/\{limit\}/g, String(limit));

const SwipesTab: React.FC = () => {
  const [config, setConfig] = useState<SwipeConfig>(DEFAULT_CONFIG);
  const [isFetching, setIsFetching] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    const fetchConfig = async () => {
      setIsFetching(true);
      try {
        const { data, error: fetchError } = await supabase
          .from('app_config')
          .select('swipe_limit, swipe_limit_title, swipe_limit_message')
          .eq('id', 1)
          .maybeSingle();

        if (fetchError) throw fetchError;

        if (data) {
          setConfig({
            swipe_limit: data.swipe_limit ?? DEFAULT_CONFIG.swipe_limit,
            swipe_limit_title:
              data.swipe_limit_title ?? DEFAULT_CONFIG.swipe_limit_title,
            swipe_limit_message:
              data.swipe_limit_message ?? DEFAULT_CONFIG.swipe_limit_message,
          });
        }
      } catch (e: any) {
        setError(e.message || 'Impossible de charger la configuration.');
      } finally {
        setIsFetching(false);
      }
    };

    fetchConfig();
  }, []);

  const handleSave = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    const limit = Number(config.swipe_limit);
    if (!Number.isInteger(limit) || limit < 1) {
      setError('La limite doit être un nombre entier supérieur ou égal à 1.');
      return;
    }
    if (!config.swipe_limit_title.trim() || !config.swipe_limit_message.trim()) {
      setError('Le titre et le message ne peuvent pas être vides.');
      return;
    }

    setIsSaving(true);
    try {
      const { error: saveError } = await supabase
        .from('app_config')
        .update({
          swipe_limit: limit,
          swipe_limit_title: config.swipe_limit_title.trim(),
          swipe_limit_message: config.swipe_limit_message.trim(),
        })
        .eq('id', 1);

      if (saveError) throw saveError;

      setSuccess(
        'Configuration enregistrée. L\'app et le site se mettent à jour en temps réel.'
      );
    } catch (e: any) {
      setError(e.message || "Erreur lors de l'enregistrement.");
    } finally {
      setIsSaving(false);
    }
  };

  if (isFetching) {
    return (
      <div className="max-w-2xl mx-auto flex items-center justify-center py-20 text-slate-400 gap-3">
        <RefreshCw className="animate-spin" size={20} />
        Chargement de la configuration...
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="bg-white p-6 md:p-8 rounded-2xl border border-slate-200 shadow-sm">
        <h2 className="text-xl font-heading mb-2 flex items-center gap-2 text-slate-900">
          <Hand className="text-primary" size={24} /> Configuration des Swipes
        </h2>
        <p className="text-sm text-slate-500 mb-6">
          Définissez le nombre de swipes gratuits par jour et le message affiché
          lorsque la limite est atteinte. Les modifications s'appliquent
          immédiatement sur l'app et sont contrôlées par la base de données.
        </p>

        <form onSubmit={handleSave} className="space-y-6">
          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700">
              Limite de swipes gratuits / jour
            </label>
            <input
              type="number"
              min={1}
              step={1}
              value={config.swipe_limit}
              onChange={(e) =>
                setConfig((c) => ({
                  ...c,
                  swipe_limit: e.target.value === '' ? 0 : parseInt(e.target.value, 10),
                }))
              }
              className="w-full px-4 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
            />
            <p className="text-xs text-slate-400">
              Au-delà de ce nombre, les utilisateurs non-premium sont bloqués
              jusqu'au lendemain.
            </p>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700">
              Titre du message de limite
            </label>
            <input
              type="text"
              value={config.swipe_limit_title}
              onChange={(e) =>
                setConfig((c) => ({ ...c, swipe_limit_title: e.target.value }))
              }
              placeholder="Limite atteinte !"
              className="w-full px-4 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all placeholder:text-slate-300"
            />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700">
              Message de limite atteinte
            </label>
            <textarea
              value={config.swipe_limit_message}
              onChange={(e) =>
                setConfig((c) => ({ ...c, swipe_limit_message: e.target.value }))
              }
              rows={3}
              placeholder="Vous avez utilisé vos {limit} swipes gratuits pour aujourd'hui."
              className="w-full px-4 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all placeholder:text-slate-300 resize-none"
            />
            <p className="text-xs text-slate-400">
              Utilisez{' '}
              <code className="px-1.5 py-0.5 bg-slate-100 rounded text-primary font-bold">
                {'{limit}'}
              </code>{' '}
              comme variable dynamique : elle sera remplacée par le nombre de
              swipes configuré.
            </p>
          </div>

          {/* Aperçu en direct du message tel qu'il apparaîtra dans l'app */}
          <div className="bg-slate-50 border border-dashed border-slate-200 rounded-2xl p-5">
            <p className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-1.5">
              <Eye size={14} /> Aperçu du message
            </p>
            <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-sm">
              <div className="flex items-center gap-2 mb-2">
                <Lock className="text-primary" size={18} />
                <span className="font-bold text-slate-900">
                  {config.swipe_limit_title || DEFAULT_CONFIG.swipe_limit_title}
                </span>
              </div>
              <p className="text-sm text-slate-600">
                {formatMessage(
                  config.swipe_limit_message ||
                    DEFAULT_CONFIG.swipe_limit_message,
                  Number(config.swipe_limit) || 0
                )}
              </p>
            </div>
          </div>

          {error && (
            <div className="bg-red-50 text-red-600 px-4 py-3 rounded-xl flex items-center gap-2 text-sm">
              <AlertCircle size={16} /> {error}
            </div>
          )}
          {success && (
            <div className="bg-green-50 text-green-600 px-4 py-3 rounded-xl flex items-center gap-2 text-sm animate-in zoom-in duration-300">
              <CheckCircle2 size={16} /> {success}
            </div>
          )}

          <button
            type="submit"
            disabled={isSaving}
            className="w-full bg-primary text-white py-3 rounded-xl font-bold hover:shadow-lg hover:shadow-primary/20 active:scale-95 transition-all disabled:opacity-50 disabled:active:scale-100 flex items-center justify-center gap-2"
          >
            {isSaving ? (
              <>
                <RefreshCw className="animate-spin" size={18} />
                Enregistrement...
              </>
            ) : (
              'Enregistrer la configuration'
            )}
          </button>
        </form>
      </div>
    </div>
  );
};

export default SwipesTab;
