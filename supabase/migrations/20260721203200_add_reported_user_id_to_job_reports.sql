-- Migration: Add reported_user_id to job_reports to allow reporting users/recruiters directly
-- Created: 2026-07-21

ALTER TABLE public.job_reports 
ADD COLUMN IF NOT EXISTS reported_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Make job_id optional (nullable) so user/recruiter reports without a specific job can be inserted
ALTER TABLE public.job_reports
ALTER COLUMN job_id DROP NOT NULL;

-- Update RLS policy to allow insertion of user/recruiter reports
DROP POLICY IF EXISTS "Users can insert own reports" ON public.job_reports;
CREATE POLICY "Users can insert own reports" ON public.job_reports 
FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can manage reports" ON public.job_reports;
CREATE POLICY "Admins can manage reports" ON public.job_reports 
FOR ALL USING (true);
