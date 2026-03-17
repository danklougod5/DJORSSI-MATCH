-- Add specialty and contract_type to jobs table
ALTER TABLE public.jobs 
ADD COLUMN IF NOT EXISTS specialty TEXT,
ADD COLUMN IF NOT EXISTS contract_type TEXT;
