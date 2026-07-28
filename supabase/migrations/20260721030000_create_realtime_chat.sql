-- Migration: Create Real-time Chat tables for Recruiters and Candidates
-- Created: 2026-07-21

-- 1. Create Chats table
CREATE TABLE IF NOT EXISTS public.recruiter_candidate_chats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    recruiter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(recruiter_id, candidate_id)
);

-- 2. Create Chat Messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chat_id UUID NOT NULL REFERENCES public.recruiter_candidate_chats(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    is_read BOOLEAN DEFAULT FALSE NOT NULL
);

-- 3. Enable RLS
ALTER TABLE public.recruiter_candidate_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for Chats
CREATE POLICY "Users can view chats they are part of"
ON public.recruiter_candidate_chats
FOR SELECT
USING (auth.uid() = recruiter_id OR auth.uid() = candidate_id);

CREATE POLICY "Recruiters can insert chats"
ON public.recruiter_candidate_chats
FOR INSERT
WITH CHECK (auth.uid() = recruiter_id);

-- 5. RLS Policies for Chat Messages
CREATE POLICY "Users can view messages in their chats"
ON public.chat_messages
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.recruiter_candidate_chats
        WHERE id = chat_messages.chat_id
        AND (recruiter_id = auth.uid() OR candidate_id = auth.uid())
    )
);

CREATE POLICY "Users can insert messages in their chats"
ON public.chat_messages
FOR INSERT
WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
        SELECT 1 FROM public.recruiter_candidate_chats
        WHERE id = chat_messages.chat_id
        AND (recruiter_id = auth.uid() OR candidate_id = auth.uid())
    )
);

-- 6. Enable Realtime replication for chat_messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
