-- Add cover letter fields to jobs table
ALTER TABLE public.jobs 
ADD COLUMN IF NOT EXISTS requires_cover_letter BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS cover_letter_instructions TEXT;
