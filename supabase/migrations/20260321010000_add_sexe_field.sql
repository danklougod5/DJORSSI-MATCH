-- Add sexe field to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS sexe TEXT CHECK (sexe IN ('Homme', 'Femme'));
