-- Migration: Set REPLICA IDENTITY FULL and UPDATE policy on profiles
ALTER TABLE public.profiles REPLICA IDENTITY FULL;

-- Allow update policy on profiles for admins / users
DROP POLICY IF EXISTS "Enable update for users and admin" ON public.profiles;
CREATE POLICY "Enable update for users and admin"
ON public.profiles
FOR UPDATE
USING (true)
WITH CHECK (true);
