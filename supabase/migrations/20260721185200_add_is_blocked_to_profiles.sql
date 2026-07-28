-- Migration: Add is_blocked column to profiles table
-- Created: 2026-07-21

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE NOT NULL;
