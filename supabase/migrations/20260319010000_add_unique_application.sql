-- Add unique constraint to prevent duplicate applications
ALTER TABLE public.applications 
ADD CONSTRAINT applications_user_id_job_id_key UNIQUE (user_id, job_id);
