-- Add job_id to swipes_log to track precisely which job was swiped
ALTER TABLE public.swipes_log ADD COLUMN IF NOT EXISTS job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE;
