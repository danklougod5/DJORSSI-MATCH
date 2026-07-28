-- Migration: Add UPDATE policy for chat_messages table to allow marking messages as read
-- Created: 2026-07-21

CREATE POLICY "Users can update messages in their chats"
ON public.chat_messages
FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.recruiter_candidate_chats
        WHERE id = chat_messages.chat_id
        AND (recruiter_id = auth.uid() OR candidate_id = auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.recruiter_candidate_chats
        WHERE id = chat_messages.chat_id
        AND (recruiter_id = auth.uid() OR candidate_id = auth.uid())
    )
);
