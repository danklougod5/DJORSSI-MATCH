-- Add required_level and experience to jobs table
ALTER TABLE public.jobs 
ADD COLUMN IF NOT EXISTS required_level TEXT,
ADD COLUMN IF NOT EXISTS experience TEXT;
