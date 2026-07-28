-- Migration: Add is_deleted column to chat_messages table
-- Created: 2026-07-21

ALTER TABLE public.chat_messages
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE NOT NULL;
