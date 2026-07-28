-- Ensure all AI adaptation and pricing columns exist on app_config
ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS cv_trial_active BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cv_trial_end_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS premium_price_cfa INTEGER NOT NULL DEFAULT 2000,
  ADD COLUMN IF NOT EXISTS extra_cv_price_cfa INTEGER NOT NULL DEFAULT 500,
  ADD COLUMN IF NOT EXISTS ai_adapt_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS ai_adapt_trial_active BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS ai_adapt_trial_end_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ai_adapt_free_limit INTEGER NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS ai_adapt_price INTEGER NOT NULL DEFAULT 500;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
