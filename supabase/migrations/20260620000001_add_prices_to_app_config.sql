-- Ajouter les prix premium et CV supplémentaires configurables à app_config
ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS premium_price_cfa INTEGER NOT NULL DEFAULT 2000;

ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS extra_cv_price_cfa INTEGER NOT NULL DEFAULT 500;

-- Forcer PostgREST à recharger le cache du schéma
NOTIFY pgrst, 'reload schema';
