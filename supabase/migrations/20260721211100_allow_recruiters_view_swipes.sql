-- Migration: Allow recruiters to view swipes on their own jobs
-- Created: 2026-07-21

CREATE POLICY "Recruiters can view swipes on their own jobs" 
ON public.swipes_log 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.jobs 
    WHERE jobs.id = swipes_log.job_id 
    AND jobs.recruiter_id = auth.uid()
  )
);
