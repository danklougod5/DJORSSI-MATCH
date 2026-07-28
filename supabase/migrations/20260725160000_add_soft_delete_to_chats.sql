-- Migration: Add soft delete flags for recruiter and candidate on recruiter_candidate_chats
-- Created: 2026-07-25

ALTER TABLE public.recruiter_candidate_chats
ADD COLUMN IF NOT EXISTS deleted_by_recruiter BOOLEAN DEFAULT FALSE NOT NULL,
ADD COLUMN IF NOT EXISTS deleted_by_candidate BOOLEAN DEFAULT FALSE NOT NULL;

-- Update RLS UPDATE policy to allow users and admins to update chats
DROP POLICY IF EXISTS "Users can update chats they are part of" ON public.recruiter_candidate_chats;
DROP POLICY IF EXISTS "Users and admins can update chats" ON public.recruiter_candidate_chats;

CREATE POLICY "Users and admins can update chats"
ON public.recruiter_candidate_chats
FOR UPDATE
USING (
  auth.uid() = recruiter_id OR 
  auth.uid() = candidate_id OR 
  (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
);
