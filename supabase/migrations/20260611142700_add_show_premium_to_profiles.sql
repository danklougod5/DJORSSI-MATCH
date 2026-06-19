-- 1. Add show_premium override column to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS show_premium BOOLEAN DEFAULT NULL;

-- 2. Set show_premium to false for the test account 'dody' initially
UPDATE public.profiles
SET show_premium = false
WHERE id = 'c43f3caf-7f1d-4882-93c6-e7c4e778de36';

-- 3. Rebuild the daily swipe limit check trigger to read and respect the show_premium override
CREATE OR REPLACE FUNCTION check_daily_swipe_limit()
RETURNS TRIGGER AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_premium_until TIMESTAMP WITH TIME ZONE;
  v_show_premium BOOLEAN;
  v_swipe_count INTEGER;
  v_limit INTEGER;
  v_message TEXT;
BEGIN
  -- Get user premium status, expiry and show_premium override
  SELECT is_premium, premium_until, show_premium INTO v_is_premium, v_premium_until, v_show_premium
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Premium (and not expired) users are never limited.
  -- Users with show_premium = false are also never limited (validation bypass).
  IF (v_is_premium AND (v_premium_until IS NULL OR v_premium_until > now())) OR (v_show_premium = false) THEN
    RETURN NEW;
  END IF;

  -- Read the dynamic limit + message (fallback to sane defaults)
  SELECT
    COALESCE(swipe_limit, 10),
    COALESCE(swipe_limit_message, 'Vous avez utilisé vos {limit} swipes gratuits pour aujourd''hui.')
  INTO v_limit, v_message
  FROM public.app_config
  WHERE id = 1;

  IF v_limit IS NULL THEN
    v_limit := 10;
  END IF;
  IF v_message IS NULL THEN
    v_message := 'Vous avez utilisé vos {limit} swipes gratuits pour aujourd''hui.';
  END IF;

  -- Count today's swipes (UTC midnight boundary)
  SELECT COUNT(*) INTO v_swipe_count
  FROM public.swipes_log
  WHERE user_id = NEW.user_id
    AND created_at >= CURRENT_DATE;

  -- If limit reached, raise exception (message reflects the configured limit)
  IF v_swipe_count >= v_limit THEN
    RAISE EXCEPTION '%', replace(v_message, '{limit}', v_limit::text);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
