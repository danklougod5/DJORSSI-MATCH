-- Add application_link and application_instructions to jobs table
ALTER TABLE public.jobs 
ADD COLUMN IF NOT EXISTS application_link TEXT,
ADD COLUMN IF NOT EXISTS application_instructions TEXT;
