-- Create swipes_log table to track all interactions
CREATE TABLE IF NOT EXISTS public.swipes_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  direction TEXT, -- 'left' or 'right'
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.swipes_log ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can insert their own swipes" ON public.swipes_log 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can see their own swipes" ON public.swipes_log 
  FOR SELECT USING (auth.uid() = user_id);
