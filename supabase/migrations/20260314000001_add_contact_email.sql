-- Add contact_email to jobs table
ALTER TABLE public.jobs 
ADD COLUMN IF NOT EXISTS contact_email TEXT;
