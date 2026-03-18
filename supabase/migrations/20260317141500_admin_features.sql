-- Add Feedback and Unsubscription tracking
CREATE TABLE IF NOT EXISTS public.feedbacks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.unsubscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reason TEXT,
    feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Scraper Control & Monitoring
CREATE TABLE IF NOT EXISTS public.scraper_control (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    command TEXT NOT NULL, -- 'start', 'stop', 'run_once'
    status TEXT DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    last_run TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS for Admin access (Simulated with a policy if we had an admin role, 
-- but for now let's allow service role or specific IDs if needed. 
-- For a demo, we'll keep it simple but record the tables exist.)

ALTER TABLE public.feedbacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.unsubscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scraper_control ENABLE ROW LEVEL SECURITY;

-- Only users can insert their own feedback/unsub
CREATE POLICY "Users can insert own feedback" ON public.feedbacks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can insert own unsubscription" ON public.unsubscriptions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admin (you) can view everything
-- Note: In a real app, we'd use a role or specific UID. 
-- For now, let's assume the dashboard will use a service role key or we'll add a policy for a specific admin UID if provided.
