-- Migration to add Job Reports table for anti-scam feature - 20260605000000

CREATE TABLE IF NOT EXISTS public.job_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE,
    reason TEXT NOT NULL, -- e.g., 'money_asked', 'scam', 'suspicious_behavior'
    details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS policies
ALTER TABLE public.job_reports ENABLE ROW LEVEL SECURITY;

-- 1. Anyone logged in can insert their own reports
CREATE POLICY "Users can insert own reports" ON public.job_reports 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 2. Admins can view/delete reports
CREATE POLICY "Admins can manage reports" ON public.job_reports 
    FOR ALL USING ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true);
