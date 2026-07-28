-- Migration pour les packs de crédits d'adaptation CV par IA
CREATE TABLE IF NOT EXISTS public.credit_packs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  credits INTEGER NOT NULL DEFAULT 1,
  price_cfa INTEGER NOT NULL DEFAULT 500,
  badge TEXT DEFAULT '',
  is_recommended BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Active RLS
ALTER TABLE public.credit_packs ENABLE ROW LEVEL SECURITY;

-- Accès en lecture publique (pour l'application Flutter et Web)
DROP POLICY IF EXISTS "Allow public read credit_packs" ON public.credit_packs;
CREATE POLICY "Allow public read credit_packs" ON public.credit_packs
  FOR SELECT USING (true);

-- Accès en gestion pour les admins
DROP POLICY IF EXISTS "Allow admin write credit_packs" ON public.credit_packs;
CREATE POLICY "Allow admin write credit_packs" ON public.credit_packs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.is_admin = true
    )
  );

-- Insertion des 3 packs par défaut
INSERT INTO public.credit_packs (id, name, credits, price_cfa, badge, is_recommended, is_active, display_order)
VALUES
  ('pack_testeur', 'Pack Testeur', 3, 500, 'Pour postuler sur un coup de cœur', false, true, 1),
  ('pack_booster', 'Pack Booster', 10, 1500, 'Meilleure valeur', true, true, 2),
  ('pack_commando', 'Pack Commando', 25, 3000, 'Pour candidats très actifs', false, true, 3)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  credits = EXCLUDED.credits,
  price_cfa = EXCLUDED.price_cfa,
  badge = EXCLUDED.badge,
  is_recommended = EXCLUDED.is_recommended,
  is_active = EXCLUDED.is_active,
  display_order = EXCLUDED.display_order;

-- Notification de rechargement de schéma PostgREST
NOTIFY pgrst, 'reload schema';
