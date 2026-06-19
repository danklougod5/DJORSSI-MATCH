-- Add columns for daily swipe tracking to profiles
ALTER TABLE public.profiles
ADD COLUMN daily_swipe_count INTEGER DEFAULT 0 NOT NULL,
ADD COLUMN last_swipe_date DATE;

-- Comment on columns for clarity
COMMENT ON COLUMN public.profiles.daily_swipe_count IS 'Number of swipes performed by the user today';
COMMENT ON COLUMN public.profiles.last_swipe_date IS 'The date of the last swipe performed by the user';
