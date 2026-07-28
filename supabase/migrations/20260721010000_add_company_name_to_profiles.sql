-- Migration: Add company_name to profiles table
-- Created: 2026-07-21

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS company_name TEXT;
