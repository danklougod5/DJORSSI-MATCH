import React, { useEffect, useState } from 'react';
import {
  Smartphone,
  AlertCircle,
  CheckCircle2,
  RefreshCw,
  Power,
  ShieldAlert,
  Download,
  Eye,
} from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface VersionConfig {
  min_version: string;
  app_stopped: boolean;
  force_update_enabled: boolean;
  maintenance_title: string;
  maintenance_message: string;
  store_url: string;
}

const DEFAULT_CONFIG: VersionConfig = {
  min_version: '1.0.0',
  app_stopped: false,
  force_update_enabled: false,
  maintenance_title: 'Application en maintenance 🛠️',
  maintenance_message:
    "L'application est temporairement suspendue pour maintenance. Veuillez réessayer ultérieurement.",
  store_url:
    'https://play.google.com/store/apps/details?id=com.djossimatch.djossimatch',
};

const VersionControlTab: React.FC = () => {
  const [config, setConfig] = useState<VersionConfig>(DEFAULT_CONFIG);
  const [isFetching, setIsFetching] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    setIsFetching(true);
    try {
      const { data, error: fetchError } = await supabase
        .from('app_config')
        .select('*')
        .eq('id', 1)
        .maybeSingle();

      if (fetchError) throw fetchError;

      if (data) {
        setConfig({
          min_version: data.min_version || DEFAULT_CONFIG.min_version,
          app_stopped: data.app_stopped === true,
          force_update_enabled: data.force_update_enabled === true,
          maintenance_title: data.maintenance_title || DEFAULT_CONFIG.maintenance_title,
          maintenance_message: data.maintenance_message || DEFAULT_CONFIG.maintenance_message,
          store_url: data.store_url || DEFAULT_CONFIG.store_url,
        });
      }
    } catch (e: any) {
      setError(e.message || 'Impossible de charger la configuration.');
    } finally {
      setIsFetching(false);
    }
  };

  const handleSave = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    if (!config.min_version.trim()) {
      setError('La version minimale requise ne peut pas être vide.');
      return;
    }

    setIsSaving(true);
    try {
      const { error: saveError } = await supabase
        .from('app_config')
        .update({
          min_version: config.min_version.trim(),
          app_stopped: config.app_stopped,
          force_update_enabled: config.force_update_enabled,
          maintenance_title: config.maintenance_title.trim(),
          maintenance_message: config.maintenance_message.trim(),
          store_url: config.store_url.trim(),
        })
        .eq('id', 1);

      if (saveError) throw saveError;

      setSuccess(
        'Configuration de version enregistrée. Les applications mobiles appliquent le changement en temps réel.'
      );
    } catch (e: any) {
      if (e.message?.includes('schema cache') || e.message?.includes('column')) {
        setError(
          "Des colonnes de version manquent dans la table Supabase 'app_config'. Veuillez exécuter le script SQL dans votre console Supabase SQL Editor pour créer les colonnes requises."
        );
      } else {
        setError(e.message || "Erreur lors de l'enregistrement.");
      }
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
      {/* Interrupteur Mode Maintenance / Arrêt d'urgence */}
      <div className={`p-6 md:p-8 rounded-2xl border transition-all ${
        config.app_stopped
          ? 'bg-red-50 border-red-300 shadow-lg shadow-red-500/10'
          : 'bg-white border-slate-200 shadow-sm'
      }`}>
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className={`w-12 h-12 rounded-xl flex items-center justify-center font-bold ${
              config.app_stopped ? 'bg-red-500 text-white animate-pulse' : 'bg-slate-100 text-slate-600'
            }`}>
              <Power size={24} />
            </div>
            <div>
              <h2 className="text-lg font-heading text-slate-900">
                Mode Arrêt / Maintenance de l'Application
              </h2>
              <p className="text-xs text-slate-500 mt-0.5">
                {config.app_stopped
                  ? "🔴 L'application est actuellement BLOQUÉE pour tous les utilisateurs."
                  : "🟢 L'application fonctionne normalement."}
              </p>
            </div>
          </div>

          <label className="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              checked={config.app_stopped}
              onChange={(e) =>
                setConfig((c) => ({ ...c, app_stopped: e.target.checked }))
              }
              className="sr-only peer"
            />
            <div className="w-14 h-7 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-red-500" />
          </label>
        </div>

        {config.app_stopped && (
          <div className="mt-4 p-4 bg-red-100/80 border border-red-200 rounded-xl flex items-start gap-3 text-red-800 text-xs font-semibold">
            <ShieldAlert size={18} className="shrink-0 text-red-600 mt-0.5" />
            <div>
              ATTENTION : Le mode arrêt est activé. Tous les utilisateurs ouvrant l'application sur iOS et Android verront un pop-up de maintenance bloquant.
            </div>
          </div>
        )}
      </div>

      {/* Formulaire de configuration */}
      <div className="bg-white p-6 md:p-8 rounded-2xl border border-slate-200 shadow-sm">
        <h2 className="text-xl font-heading mb-2 flex items-center gap-2 text-slate-900">
          <Smartphone className="text-primary" size={24} /> Gestion de Version & Mise à Jour Forcée
        </h2>
        <p className="text-sm text-slate-500 mb-6">
          Activez ou désactivez le pop-up de mise à jour forcée et définissez la version minimale requise.
        </p>

        <form onSubmit={handleSave} className="space-y-6">
          {/* Toggle Activer / Désactiver le Pop-up de Version */}
          <div className="p-4 bg-slate-50 border border-slate-200 rounded-xl flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-bold text-slate-800 block">
                Activer le pop-up de mise à jour forcée
              </span>
              <span className="text-xs text-slate-500 block mt-0.5">
                {config.force_update_enabled
                  ? '🟠 Le pop-up s\'affichera sur les téléphones si la version installée est inférieure à la version requise.'
                  : '⚪ Désactivé : Aucun pop-up de mise à jour ne sera affiché aux utilisateurs.'}
              </span>
            </div>

            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={config.force_update_enabled}
                onChange={(e) =>
                  setConfig((c) => ({ ...c, force_update_enabled: e.target.checked }))
                }
                className="sr-only peer"
              />
              <div className="w-14 h-7 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-primary" />
            </label>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700">
              Version minimale requise (ex: 1.0.0, 1.2.0)
            </label>
            <input
              type="text"
              value={config.min_version}
              onChange={(e) =>
                setConfig((c) => ({ ...c, min_version: e.target.value }))
              }
              placeholder="1.0.0"
              className="w-full px-4 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
            />
            <p className="text-xs text-slate-400">
              Si la version installée sur le téléphone de l'utilisateur est inférieure à cette valeur ET que le pop-up est activé, l'application affichera la modale de mise à jour.
            </p>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700">
              Titre du message de maintenance / arrêt
            </label>
            <input
              type="text"
              value={config.maintenance_title}
              onChange={(e) =>
                setConfig((c) => ({ ...c, maintenance_title: e.target.value }))
              }
              placeholder="Application en maintenance 🛠️"
              className="w-full px-4 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
            />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700">
              Message de maintenance / arrêt
            </label>
            <textarea
              value={config.maintenance_message}
              onChange={(e) =>
                setConfig((c) => ({ ...c, maintenance_message: e.target.value }))
              }
              rows={3}
              placeholder="L'application est temporairement suspendue..."
              className="w-full px-4 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all resize-none"
            />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-semibold text-slate-700 flex items-center gap-1.5">
              <Download size={16} /> Lien du Play Store / App Store
            </label>
            <input
              type="text"
              value={config.store_url}
              onChange={(e) =>
                setConfig((c) => ({ ...c, store_url: e.target.value }))
              }
              placeholder="https://play.google.com/store/apps/details?id=com.djossimatch.djossimatch"
              className="w-full px-4 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
            />
          </div>

          {/* Aperçu en direct */}
          <div className="bg-slate-50 border border-dashed border-slate-200 rounded-2xl p-5">
            <p className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-1.5">
              <Eye size={14} /> Aperçu du pop-up sur mobile
            </p>
            <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-sm space-y-2">
              <div className="flex items-center gap-2">
                {config.app_stopped ? (
                  <Power className="text-red-500" size={20} />
                ) : (
                  <Download className="text-primary" size={20} />
                )}
                <span className="font-bold text-slate-900">
                  {config.app_stopped
                    ? config.maintenance_title
                    : 'Mise à jour requise'}
                </span>
              </div>
              <p className="text-sm text-slate-600">
                {config.app_stopped
                  ? config.maintenance_message
                  : 'Une nouvelle version importante de Djorssi-Match est disponible. Veuillez mettre à jour l\'application.'}
              </p>
              <div className="pt-2">
                <button
                  type="button"
                  className={`w-full py-2.5 rounded-xl font-bold text-white text-xs ${
                    config.app_stopped ? 'bg-slate-800' : 'bg-primary'
                  }`}
                >
                  {config.app_stopped ? 'Réessayer' : 'METTRE À JOUR MAINTENANT'}
                </button>
              </div>
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

export default VersionControlTab;
