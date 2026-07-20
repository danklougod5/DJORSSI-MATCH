-- Activer le Realtime sur les tables jobs et app_announcements
-- Cela permet aux clients Supabase (Flutter) de recevoir des événements INSERT/UPDATE/DELETE en temps réel

ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
ALTER PUBLICATION supabase_realtime ADD TABLE app_announcements;
