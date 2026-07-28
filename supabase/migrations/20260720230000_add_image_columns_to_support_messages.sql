-- Migration: Add image_url and admin_image_url columns to support_messages table
-- This allows users to attach screenshots/images to their questions/suggestions, and admins to reply with images.

ALTER TABLE public.support_messages
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS admin_image_url TEXT;

-- Comment on columns
COMMENT ON COLUMN public.support_messages.image_url IS 'Public URL of the screenshot/image attached by the candidate';
COMMENT ON COLUMN public.support_messages.admin_image_url IS 'Public URL of the screenshot/image attached by the admin in their reply';

-- Force schema reload
NOTIFY pgrst, 'reload schema';
