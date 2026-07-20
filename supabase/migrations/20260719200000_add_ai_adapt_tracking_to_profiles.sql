-- Ajouter les colonnes de suivi mensuel des adaptations IA dans profiles (côté serveur)
-- Ceci remplace le stockage local (SharedPreferences) qui pouvait être contourné
-- en supprimant et réinstallant l'application.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS ai_adapt_monthly_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ai_adapt_month TEXT; -- Format: 'YYYY-MM'

-- Commentaires pour la clarté
COMMENT ON COLUMN public.profiles.ai_adapt_monthly_count IS 'Number of AI CV adaptations performed by the user in the current month (server-side, cannot be bypassed by reinstalling the app)';
COMMENT ON COLUMN public.profiles.ai_adapt_month IS 'The month (YYYY-MM) for which ai_adapt_monthly_count is tracked. When a new month starts, the count is reset automatically.';

-- Forcer PostgREST à recharger le cache du schéma
NOTIFY pgrst, 'reload schema';
