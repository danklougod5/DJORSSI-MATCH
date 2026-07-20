-- Ajouter les colonnes de configuration pour l'adaptation de CV par l'IA à app_config
ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS ai_adapt_trial_active BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS ai_adapt_trial_end_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ai_adapt_free_limit INTEGER NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS ai_adapt_price INTEGER NOT NULL DEFAULT 500;

-- Forcer PostgREST à recharger le cache du schéma
NOTIFY pgrst, 'reload schema';
