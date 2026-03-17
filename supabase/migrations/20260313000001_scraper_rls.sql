-- Allow Service role / Anon role to insert jobs (for the scraper)
CREATE POLICY "Allow scraper to insert jobs" ON public.jobs FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow scraper to update jobs" ON public.jobs FOR UPDATE USING (true);
