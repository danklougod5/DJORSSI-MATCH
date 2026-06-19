-- Performance indexes to reduce Disk IO budget consumption.
-- These address the 504 timeouts and auth lock failures caused by exhausted IO budget.
--
-- Note: We build these without CONCURRENTLY to avoid blocking/timeouts on active transactions
-- and to ensure they complete immediately in a single pass.

-- Drop existing or invalid indexes if they failed in previous attempts
DROP INDEX IF EXISTS public.idx_swipes_log_user_created;
DROP INDEX IF EXISTS public.idx_swipes_log_user_job;
DROP INDEX IF EXISTS public.idx_profiles_is_premium;
DROP INDEX IF EXISTS public.idx_jobs_is_approved;
DROP INDEX IF EXISTS public.idx_jobs_approved_created;

-- 1. swipes_log: Used by check_daily_swipe_limit() trigger on EVERY insert.
CREATE INDEX idx_swipes_log_user_created
  ON public.swipes_log(user_id, created_at DESC);

-- 2. swipes_log: Used by the Flutter app to load all swiped job IDs for a user.
CREATE INDEX idx_swipes_log_user_job
  ON public.swipes_log(user_id, job_id);

-- 3. profiles: Used by admin dashboard to count premium users (SELECT count WHERE is_premium = true).
CREATE INDEX idx_profiles_is_premium
  ON public.profiles(is_premium);

-- 4. jobs: Used by admin dashboard to count pending approvals and by Flutter to filter approved jobs.
CREATE INDEX idx_jobs_is_approved
  ON public.jobs(is_approved);

-- 5. jobs: Composite index for the most common Flutter query pattern:
CREATE INDEX idx_jobs_approved_created
  ON public.jobs(is_approved, created_at DESC);

