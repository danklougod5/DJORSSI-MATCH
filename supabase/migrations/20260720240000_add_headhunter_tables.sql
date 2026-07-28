-- Migration: Add Headhunter (CV Swipe) Tables and Columns
-- Created: 2026-07-20

-- 1. Add visibility toggle field to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_visible_to_recruiters BOOLEAN DEFAULT FALSE;

-- 2. Add performance index on visibility flag for fast headhunter queries
CREATE INDEX IF NOT EXISTS idx_profiles_visible_to_recruiters 
ON public.profiles(is_visible_to_recruiters) 
WHERE is_visible_to_recruiters = TRUE;

-- 3. Create recruiter_swipes table to log recruiter actions
CREATE TABLE IF NOT EXISTS public.recruiter_swipes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    recruiter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('like', 'dislike')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(recruiter_id, candidate_id)
);

-- 4. Enable RLS on the swipes table
ALTER TABLE public.recruiter_swipes ENABLE ROW LEVEL SECURITY;

-- 5. Add RLS Policies for recruiter_swipes
CREATE POLICY "Recruiters can view their own swipes" 
ON public.recruiter_swipes 
FOR SELECT 
USING (auth.uid() = recruiter_id);

CREATE POLICY "Recruiters can insert their own swipes" 
ON public.recruiter_swipes 
FOR INSERT 
WITH CHECK (auth.uid() = recruiter_id);

-- 6. Add SELECT policy on profiles table for headhunting
-- Any logged in user can view profiles that have chosen to be visible to recruiters
CREATE POLICY "Logged in users can view profiles visible to recruiters" 
ON public.profiles 
FOR SELECT 
USING (is_visible_to_recruiters = TRUE);
