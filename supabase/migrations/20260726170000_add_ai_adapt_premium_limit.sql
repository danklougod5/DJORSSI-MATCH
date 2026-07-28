-- Migration pour ajouter la limite d'adaptations IA gratuites par mois pour les utilisateurs Premium
ALTER TABLE public.app_config 
  ADD COLUMN IF NOT EXISTS ai_adapt_premium_limit INTEGER NOT NULL DEFAULT 5;

UPDATE public.app_config 
SET ai_adapt_premium_limit = 5 
WHERE id = 1 AND (ai_adapt_premium_limit IS NULL OR ai_adapt_premium_limit = 0);

COMMENT ON COLUMN public.app_config.ai_adapt_premium_limit IS 'Nombre d adaptatifs IA gratuits par mois inclus avec l abonnement Premium';
