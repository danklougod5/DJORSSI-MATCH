-- Migration: Add is_read column to support_messages to track unread replies
-- When a user sends a message, is_read = true (no unread replies).
-- When an admin replies, is_read = false (user has an unread reply).
-- When a user views the message, it is set back to true.

ALTER TABLE public.support_messages
ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT true;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
