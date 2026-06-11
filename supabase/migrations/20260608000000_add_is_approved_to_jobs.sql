-- Migration to add is_approved column to jobs table - 20260608000000

ALTER TABLE public.jobs
ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT TRUE;
