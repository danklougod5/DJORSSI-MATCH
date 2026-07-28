-- Migration: Allow recruiters and candidates to update chats they are part of (to support UPSERT operations)
-- Created: 2026-07-21

DROP POLICY IF EXISTS "Users can update chats they are part of" ON public.recruiter_candidate_chats;

CREATE POLICY "Users can update chats they are part of"
ON public.recruiter_candidate_chats
FOR UPDATE
USING (auth.uid() = recruiter_id OR auth.uid() = candidate_id);
