-- Migration: Add company_industry and company_size to profiles table
-- Created: 2026-07-21

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS company_industry TEXT,
ADD COLUMN IF NOT EXISTS company_size TEXT;
