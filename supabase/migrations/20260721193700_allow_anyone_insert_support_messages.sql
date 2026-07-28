-- Migration: Allow anyone to insert support messages (including blocked users requesting unblock)
-- Created: 2026-07-21

DROP POLICY IF EXISTS "Users can insert their own support messages" ON public.support_messages;
CREATE POLICY "Anyone can insert support messages"
ON public.support_messages
FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can view all support messages" ON public.support_messages;
CREATE POLICY "Anyone or admin can view support messages"
ON public.support_messages
FOR SELECT
USING (true);
