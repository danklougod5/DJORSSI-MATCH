-- Create ios_waitlist table
CREATE TABLE IF NOT EXISTS public.ios_waitlist (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Set up Row Level Security
ALTER TABLE public.ios_waitlist ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts (anyone can join the waitlist)
CREATE POLICY "Allow public insert to ios_waitlist" 
ON public.ios_waitlist FOR INSERT 
TO public 
WITH CHECK (true);

-- Allow admins to view the list (assuming admin access via dashboard uses service role or admin flag)
CREATE POLICY "Allow admins to read ios_waitlist" 
ON public.ios_waitlist FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() AND profiles.is_admin = true
    )
);
