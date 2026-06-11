-- Make the daily swipe limit and its "limit reached" message dynamic.
-- Single source of truth: public.app_config (row id = 1), consumed by the
-- Flutter app, the web admin dashboard and the DB trigger below.

-- 1. Ensure app_config exists (it is normally created from the dashboard).
CREATE TABLE IF NOT EXISTS public.app_config (
  id INTEGER PRIMARY KEY
);

-- 2. Add the dynamic swipe configuration columns.
ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS swipe_limit INTEGER NOT NULL DEFAULT 10;

ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS swipe_limit_title TEXT NOT NULL DEFAULT 'Limite atteinte !';

-- {limit} is replaced at runtime by the configured number of swipes.
ALTER TABLE public.app_config
  ADD COLUMN IF NOT EXISTS swipe_limit_message TEXT NOT NULL
  DEFAULT 'Vous avez utilisé vos {limit} swipes gratuits pour aujourd''hui.';

-- 3. The config row (id=1) is managed via the Supabase dashboard and already
--    exists in production. No INSERT here — the real table has a 'key TEXT NOT NULL'
--    primary key, so a bare INSERT would violate the NOT NULL constraint on 'key'.

-- 4. Enable Row Level Security and define access policies.
--    (Same pattern as jobs/job_reports: public read, admin-only writes.)
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Everyone (anon + authenticated) can read the public app configuration.
DROP POLICY IF EXISTS "Anyone can read app_config" ON public.app_config;
CREATE POLICY "Anyone can read app_config" ON public.app_config
  FOR SELECT USING (true);

-- Only admins (profiles.is_admin = true) can modify the configuration.
DROP POLICY IF EXISTS "Admins can manage app_config" ON public.app_config;
CREATE POLICY "Admins can manage app_config" ON public.app_config
  FOR ALL
  USING ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true)
  WITH CHECK ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true);

-- 5. Rebuild the limit trigger to read the limit + message from app_config.
CREATE OR REPLACE FUNCTION check_daily_swipe_limit()
RETURNS TRIGGER AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_premium_until TIMESTAMP WITH TIME ZONE;
  v_swipe_count INTEGER;
  v_limit INTEGER;
  v_message TEXT;
BEGIN
  -- Get user premium status and expiry
  SELECT is_premium, premium_until INTO v_is_premium, v_premium_until
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Premium (and not expired) users are never limited
  IF v_is_premium AND (v_premium_until IS NULL OR v_premium_until > now()) THEN
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

-- 6. Force PostgREST to refresh its schema cache so the new columns are
--    immediately visible to the web app / admin dashboard (avoids the
--    "Could not find the 'swipe_limit' column ... in the schema cache" error).
NOTIFY pgrst, 'reload schema';
