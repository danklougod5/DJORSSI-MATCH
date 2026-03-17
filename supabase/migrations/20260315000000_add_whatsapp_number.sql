-- Add whatsapp_number to jobs table
ALTER TABLE public.jobs 
ADD COLUMN IF NOT EXISTS whatsapp_number TEXT;
