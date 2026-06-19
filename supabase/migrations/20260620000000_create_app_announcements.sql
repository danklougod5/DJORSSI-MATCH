-- Create app_announcements table
CREATE TABLE IF NOT EXISTS public.app_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL CHECK (type IN ('discount', 'update', 'info')),
  is_active boolean NOT NULL DEFAULT true,
  cta_label text,
  cta_url text,
  created_at timestamp with time zone DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.app_announcements ENABLE ROW LEVEL SECURITY;

-- Policy: Allow anyone (anon or authenticated) to read active announcements
CREATE POLICY "Allow public read access to active announcements" 
  ON public.app_announcements FOR SELECT 
  TO authenticated, anon
  USING (is_active = true);

-- Policy: Allow admins full access to announcements
CREATE POLICY "Allow full access to admin users" 
  ON public.app_announcements FOR ALL 
  TO authenticated
  USING ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true)
  WITH CHECK ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true);
