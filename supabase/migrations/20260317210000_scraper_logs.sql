CREATE TABLE IF NOT EXISTS public.scraper_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    level TEXT DEFAULT 'INFO',
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.scraper_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin can view scraper logs" ON public.scraper_logs FOR SELECT USING (true);
