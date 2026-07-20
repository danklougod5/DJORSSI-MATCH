-- Ajouter un compteur de slots CV utilisés dans profiles.
-- Ce compteur UNIQUEMENT monte (jamais décrémenté à la suppression d'un CV),
-- ce qui empêche le contournement du quota en supprimant puis recréant un CV.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS cv_slots_used INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.profiles.cv_slots_used IS 'Total number of CV creation slots consumed by the user ever. Only incremented on creation, never decremented on deletion. Used to prevent quota bypass.';

-- Initialiser le compteur pour les utilisateurs existants
-- en comptant leurs CVs actuels dans user_cvs.
UPDATE public.profiles p
SET cv_slots_used = (
  SELECT COUNT(*) FROM public.user_cvs c WHERE c.user_id = p.id
)
WHERE p.cv_slots_used = 0;

-- Forcer PostgREST à recharger le cache du schéma
NOTIFY pgrst, 'reload schema';
