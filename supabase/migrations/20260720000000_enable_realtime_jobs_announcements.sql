-- Activer le Realtime sur les tables jobs et app_announcements
-- Cela permet aux clients Supabase (Flutter) de recevoir des événements INSERT/UPDATE/DELETE en temps réel

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_rel pr
    JOIN pg_publication p ON p.oid = pr.prpubid
    JOIN pg_class c ON c.oid = pr.prrelid
    WHERE p.pubname = 'supabase_realtime' AND c.relname = 'jobs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_rel pr
    JOIN pg_publication p ON p.oid = pr.prpubid
    JOIN pg_class c ON c.oid = pr.prrelid
    WHERE p.pubname = 'supabase_realtime' AND c.relname = 'app_announcements'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE app_announcements;
  END IF;
END $$;
