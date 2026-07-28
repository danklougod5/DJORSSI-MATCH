-- Migration: Add Recruiter Role field to profiles table
-- Created: 2026-07-20

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_recruiter BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_profiles_is_recruiter 
ON public.profiles(is_recruiter) 
WHERE is_recruiter = TRUE;
