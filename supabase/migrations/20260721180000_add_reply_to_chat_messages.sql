-- Migration: Add reply-to fields to chat_messages table
-- Created: 2026-07-21

ALTER TABLE public.chat_messages
ADD COLUMN IF NOT EXISTS reply_to_message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS reply_to_text TEXT,
ADD COLUMN IF NOT EXISTS reply_to_sender TEXT;
