-- Migration pour ajouter la gestion individuelle d activation/désactivation des avantages Premium dans app_config
ALTER TABLE public.app_config 
  ADD COLUMN IF NOT EXISTS feat_unlimited_swipes BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS feat_unlocked_history BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS feat_certified_badge BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS feat_rewind BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS feat_email_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS feat_extra_cvs BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS feat_ai_adaptation BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE public.app_config 
SET 
  feat_unlimited_swipes = COALESCE(feat_unlimited_swipes, TRUE),
  feat_unlocked_history = COALESCE(feat_unlocked_history, TRUE),
  feat_certified_badge = COALESCE(feat_certified_badge, TRUE),
  feat_rewind = COALESCE(feat_rewind, TRUE),
  feat_email_alerts = COALESCE(feat_email_alerts, TRUE),
  feat_extra_cvs = COALESCE(feat_extra_cvs, TRUE),
  feat_ai_adaptation = COALESCE(feat_ai_adaptation, TRUE)
WHERE id = 1;
