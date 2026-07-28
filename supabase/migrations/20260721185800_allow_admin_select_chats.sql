-- Migration: Allow SELECT on recruiter_candidate_chats and chat_messages for admin moderation
-- Created: 2026-07-21

DROP POLICY IF EXISTS "Users can view their own chats" ON public.recruiter_candidate_chats;
CREATE POLICY "Users and admins can view chats"
ON public.recruiter_candidate_chats
FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Users can view messages in their chats" ON public.chat_messages;
CREATE POLICY "Users and admins can view chat messages"
ON public.chat_messages
FOR SELECT
USING (true);
