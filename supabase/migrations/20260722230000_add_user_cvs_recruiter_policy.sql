-- Migration: Allow recruiters to view CVs of candidates visible to recruiters
-- Created: 2026-07-22

CREATE POLICY "Recruiters can view CVs of visible candidates"
ON public.user_cvs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = user_cvs.user_id
    AND (p.is_visible_to_recruiters = TRUE OR p.id = auth.uid())
  )
);
