-- Stop bloating DB: Truncate logs and control tables
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'scraper_logs') THEN
        TRUNCATE TABLE public.scraper_logs;
    END IF;
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'scraper_control') THEN
        TRUNCATE TABLE public.scraper_control;
    END IF;
END $$;
