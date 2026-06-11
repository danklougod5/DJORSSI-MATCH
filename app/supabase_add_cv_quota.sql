-- Migration: Add extra_cvs_purchased column to profiles table
-- This tracks how many additional CV slots a user has purchased (500 F CFA each)

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS extra_cvs_purchased INTEGER DEFAULT 0;

-- Add a comment for clarity
COMMENT ON COLUMN profiles.extra_cvs_purchased IS 'Number of additional CV creation slots purchased at 500 F CFA each';
