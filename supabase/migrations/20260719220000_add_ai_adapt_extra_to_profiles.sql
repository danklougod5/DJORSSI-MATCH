-- Ajouter la colonne ai_adapt_extra_purchased dans profiles
-- Permet d'attribuer des adaptations IA de CV supplémentaires à un utilisateur
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS ai_adapt_extra_purchased INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.profiles.ai_adapt_extra_purchased IS 'Number of extra AI CV adaptations purchased or allocated to the user';

-- Forcer PostgREST à recharger le cache du schéma
NOTIFY pgrst, 'reload schema';
