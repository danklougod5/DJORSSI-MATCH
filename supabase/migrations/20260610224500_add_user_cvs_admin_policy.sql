-- Migration: Add policy to allow admins to view all user CVs
-- This allows calculating metrics and displaying the user list on the web admin dashboard.

CREATE POLICY "Admins can view all CVs" ON public.user_cvs
  FOR SELECT USING (
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
  );
