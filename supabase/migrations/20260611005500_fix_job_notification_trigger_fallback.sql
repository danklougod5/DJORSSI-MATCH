-- Redefine public.handle_new_job_notification() to check both active job_alerts and fallback profiles.skills
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
        'Authorization', 'Bearer ' || COALESCE(
          (SELECT value FROM decode(get_auth_key('service_role'))),
          current_setting('request.headers', true)::jsonb->>'authorization',
          ''
        )
      ),
      body := jsonb_build_object('job_id', NEW.id)
    );
    
    RAISE NOTICE 'New matching job found! ID: %, Tags: %', NEW.id, NEW.tags;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
