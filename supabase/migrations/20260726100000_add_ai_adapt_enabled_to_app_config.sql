-- Ajouter un vrai flag d'activation du générateur d'adaptation IA de CV.
-- Il est distinct du mode essai gratuit / packs de crédits.
ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS ai_adapt_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- Forcer PostgREST à recharger le cache du schéma
NOTIFY pgrst, 'reload schema';
