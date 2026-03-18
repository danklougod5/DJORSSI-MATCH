-- Migration to add Job Alerts functionality - 20260317133000

-- 1. Job Alerts Table
CREATE TABLE IF NOT EXISTS public.job_alerts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    sectors TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id)
);

-- RLS for Job Alerts
ALTER TABLE public.job_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own alerts" ON public.job_alerts;
CREATE POLICY "Users can view their own alerts" ON public.job_alerts
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own alerts" ON public.job_alerts;
CREATE POLICY "Users can create their own alerts" ON public.job_alerts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own alerts" ON public.job_alerts;
CREATE POLICY "Users can update their own alerts" ON public.job_alerts
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own alerts" ON public.job_alerts;
CREATE POLICY "Users can delete their own alerts" ON public.job_alerts
    FOR DELETE USING (auth.uid() = user_id);

-- 2. Function to notify when a new job is added
-- This function will trigger an Edge Function invocation
CREATE OR REPLACE FUNCTION public.handle_new_job_notification()
RETURNS TRIGGER AS $$
DECLARE
  edge_function_url TEXT;
  service_role_key TEXT;
BEGIN
  -- Note: These values should ideally be set in your Supabase Project
  -- In a real production environment, you might use HTTP extensions or 
  -- just rely on Webhooks feature in Supabase Dashboard (Database -> Webhooks)
  -- This SQL approach is for demonstration of the "automated" logic.
  
  -- We'll try to find if public.jobs has tags that match ANY user alerts
  -- If yes, we invoke the edge function.
  
  IF EXISTS (
    SELECT 1 FROM public.job_alerts 
    WHERE is_active = true 
    AND sectors && NEW.tags
  ) THEN
    -- Invoke Edge Function (Webhook style)
    -- This assumes pg_net is enabled. If not, this part might fail silently or error.
    -- Better practice: Use Supabase Dashboard Database Webhooks for better reliability.
    
    -- PERFORM net.http_post(
    --   url := 'https://tbhxbfunyhbrctzfpkwf.supabase.co/functions/v1/notify-job-alerts',
    --   headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'),
    --   body := jsonb_build_object('job_id', NEW.id)
    -- );
    
    RAISE NOTICE 'New matching job found! ID: %, Tags: %', NEW.id, NEW.tags;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger ONLY on INSERT of a new job
DROP TRIGGER IF EXISTS on_job_inserted ON public.jobs;
CREATE TRIGGER on_job_inserted
  AFTER INSERT ON public.jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_job_notification();
