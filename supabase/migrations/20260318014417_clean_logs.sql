-- Stop bloating DB: Truncate logs and control tables
TRUNCATE TABLE public.scraper_logs;
TRUNCATE TABLE public.scraper_control;
