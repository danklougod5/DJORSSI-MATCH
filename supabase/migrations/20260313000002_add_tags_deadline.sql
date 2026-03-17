-- Add tags and deadline to jobs table
ALTER TABLE public.jobs 
ADD COLUMN IF NOT EXISTS tags TEXT[],
ADD COLUMN IF NOT EXISTS deadline TEXT;
