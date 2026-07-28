-- Migration: Ensure foreign key constraint between user_cvs and profiles
-- Created: 2026-07-22

-- Delete orphan rows whose user_id is no longer in profiles
DELETE FROM public.user_cvs WHERE user_id NOT IN (SELECT id FROM public.profiles);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'user_cvs_user_id_profiles_fkey'
  ) THEN
    ALTER TABLE public.user_cvs
      ADD CONSTRAINT user_cvs_user_id_profiles_fkey
      FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END $$;
