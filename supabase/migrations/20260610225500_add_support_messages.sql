-- Migration: Add support_messages table for Suggestions and Q&A
-- This table allows mobile users to submit questions/suggestions and admins to reply.

CREATE TABLE IF NOT EXISTS public.support_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    message_type TEXT NOT NULL CHECK (message_type IN ('suggestion', 'question')),
    content TEXT NOT NULL,
    admin_reply TEXT,
    replied_at TIMESTAMP WITH TIME ZONE,
    replied_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index to query user support history fast
CREATE INDEX IF NOT EXISTS idx_support_messages_user_id ON public.support_messages(user_id);

-- Enable Row Level Security
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

-- 1. Users can view their own support messages
CREATE POLICY "Users can view their own support messages" ON public.support_messages
  FOR SELECT USING (auth.uid() = user_id);

-- 2. Users can insert their own support messages
CREATE POLICY "Users can insert their own support messages" ON public.support_messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 3. Admins can view all support messages
CREATE POLICY "Admins can view all support messages" ON public.support_messages
  FOR SELECT USING (
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
  );

-- 4. Admins can update support messages (to reply)
CREATE POLICY "Admins can reply to support messages" ON public.support_messages
  FOR UPDATE USING (
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
  ) WITH CHECK (
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
  );

-- Trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION public.handle_support_messages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_support_messages_update ON public.support_messages;
CREATE TRIGGER on_support_messages_update
  BEFORE UPDATE ON public.support_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_support_messages_updated_at();

-- Force schema reload
NOTIFY pgrst, 'reload schema';
