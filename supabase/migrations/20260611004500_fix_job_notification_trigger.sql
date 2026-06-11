-- Redefine public.handle_new_job_notification() to check is_approved = true
CREATE OR REPLACE FUNCTION public.handle_new_job_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger notification if the job is approved
  IF NEW.is_approved = true AND EXISTS (
    SELECT 1 FROM public.job_alerts 
    WHERE is_active = true 
    AND sectors && NEW.tags
  ) THEN
    -- Invoke Edge Function (Webhook style)
    PERFORM net.http_post(
      url := 'https://tbhxbfunyhbrctzfpkwf.supabase.co/functions/v1/notify-job-alerts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json', 
        'Authorization', 'Bearer ' || COALESCE(
          (SELECT value FROM decode(get_auth_key('service_role'))), -- If custom helper exists
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
