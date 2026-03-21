-- Add premium_until column to profiles to handle monthly subscriptions
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS premium_until TIMESTAMP WITH TIME ZONE;

-- Update the swipe limit trigger to check for expiry
CREATE OR REPLACE FUNCTION check_daily_swipe_limit()
RETURNS TRIGGER AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_premium_until TIMESTAMP WITH TIME ZONE;
  v_swipe_count INTEGER;
BEGIN
  -- Get user premium status and expiry
  SELECT is_premium, premium_until INTO v_is_premium, v_premium_until 
  FROM public.profiles 
  WHERE id = NEW.user_id;
  
  -- Check if user is premium AND subscription has not expired
  -- If premium_until is NULL but is_premium is TRUE, we consider it lifetime or legacy
  IF v_is_premium AND (v_premium_until IS NULL OR v_premium_until > now()) THEN
    RETURN NEW;
  END IF;

  -- Count today's swipes (UTC midnight boundary)
  -- If v_is_premium was true but expired, they fall back to the 10 free swipes limit
  SELECT COUNT(*) INTO v_swipe_count 
  FROM public.swipes_log 
  WHERE user_id = NEW.user_id 
    AND created_at >= CURRENT_DATE;

  -- If limit reached, raise exception to prevent insert
  IF v_swipe_count >= 10 THEN
    RAISE EXCEPTION 'Limite de 10 swipes gratuits par jour atteinte. Passez au Premium !';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
