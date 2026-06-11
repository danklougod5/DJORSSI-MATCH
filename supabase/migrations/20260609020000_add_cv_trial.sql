-- Période d'essai gratuite pour le générateur de CV.
-- Contrôlée depuis le dashboard admin : activer/désactiver manuellement.
-- Quand active (cv_trial_active = true) ET que la date de fin n'est pas dépassée,
-- le paywall est bypassé côté app Flutter sans aucun paiement requis.

-- 1. Ajouter les colonnes à app_config (la table existe déjà en prod).
ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS cv_trial_active BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS cv_trial_end_date TIMESTAMPTZ;

-- 2. Forcer PostgREST à recharger son cache de schéma immédiatement.
NOTIFY pgrst, 'reload schema';
