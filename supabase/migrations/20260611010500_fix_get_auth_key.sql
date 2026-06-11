-- Redefine handle_new_job_notification() to fix get_auth_key compilation error
CREATE OR REPLACE FUNCTION public.handle_new_job_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger notification if the job is approved
  IF NEW.is_approved = true AND (
    EXISTS (
      -- Case 1: Active matching job alerts
      SELECT 1 FROM public.job_alerts 
      WHERE is_active = true 
      AND sectors && NEW.tags
    ) OR EXISTS (
      -- Case 2: Matching premium profiles whose skills overlap NEW.tags and who don't have a job_alerts configuration
      SELECT 1 FROM public.profiles p
      WHERE p.is_premium = true 
      AND (p.premium_until IS NULL OR p.premium_until > now())
      AND p.skills && NEW.tags
      AND NOT EXISTS (
        SELECT 1 FROM public.job_alerts a 
        WHERE a.user_id = p.id
      )
    )
  ) THEN
    -- Invoke Edge Function (Webhook style)
    PERFORM net.http_post(
      url := 'https://tbhxbfunyhbrctzfpkwf.supabase.co/functions/v1/notify-job-alerts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json', 
        'Authorization', COALESCE(
          current_setting('request.headers', true)::jsonb->>'authorization',
          'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiaHhiZnVueWhicmN0emZwa3dmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzOTc0ODksImV4cCI6MjA4ODk3MzQ4OX0.9XH6DYYFqsX3Tdf7DEpgX65A5nNGYQDfBI_yjie_WOo'
        )
      ),
      body := jsonb_build_object('job_id', NEW.id)
    );
    
    RAISE NOTICE 'New matching job found! ID: %, Tags: %', NEW.id, NEW.tags;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
