-- Apply a default 21-day deadline to jobs that do not provide one.
-- This keeps old offers from staying visible indefinitely.

CREATE OR REPLACE FUNCTION public.set_default_job_deadline()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  base_created_at timestamptz;
BEGIN
  IF NEW.deadline IS NOT NULL AND btrim(NEW.deadline) <> '' THEN
    RETURN NEW;
  END IF;

  base_created_at := COALESCE(NEW.created_at, timezone('utc'::text, now()));

  NEW.deadline := to_char(
    (base_created_at + interval '21 days')::date,
    'YYYY-MM-DD'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS jobs_set_default_deadline ON public.jobs;

CREATE TRIGGER jobs_set_default_deadline
BEFORE INSERT OR UPDATE ON public.jobs
FOR EACH ROW
EXECUTE FUNCTION public.set_default_job_deadline();

UPDATE public.jobs
SET deadline = to_char(
  (COALESCE(created_at, timezone('utc'::text, now())) + interval '21 days')::date,
  'YYYY-MM-DD'
)
WHERE deadline IS NULL OR btrim(deadline) = '';
