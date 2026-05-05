-- Secure the swiping limit with a PostgreSQL trigger
CREATE OR REPLACE FUNCTION check_daily_swipe_limit()
RETURNS TRIGGER AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_swipe_count INTEGER;
BEGIN
  -- Get user premium status
  SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = NEW.user_id;
  
  -- If premium, skip check
  IF v_is_premium THEN
    RETURN NEW;
  END IF;

  -- Count today's swipes (UTC midnight boundary)
  SELECT COUNT(*) INTO v_swipe_count 
  FROM public.swipes_log 
  WHERE user_id = NEW.user_id 
    AND created_at >= CURRENT_DATE;

  -- If limit reached, raise exception to prevent insert
  IF v_swipe_count >= 80 THEN
    RAISE EXCEPTION 'Daily free swipe limit reached (80)';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if it exists to allow idempotent re-runs
DROP TRIGGER IF EXISTS enforce_swipe_limit ON public.swipes_log;

-- Create the before insert trigger
CREATE TRIGGER enforce_swipe_limit
BEFORE INSERT ON public.swipes_log
FOR EACH ROW
EXECUTE FUNCTION check_daily_swipe_limit();
