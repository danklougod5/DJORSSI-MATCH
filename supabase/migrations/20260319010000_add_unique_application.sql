-- Add unique constraint to prevent duplicate applications
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'applications_user_id_job_id_key'
  ) THEN
    ALTER TABLE public.applications ADD CONSTRAINT applications_user_id_job_id_key UNIQUE (user_id, job_id);
  END IF;
END $$;
