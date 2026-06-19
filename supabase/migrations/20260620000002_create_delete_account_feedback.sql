-- Créer la table pour stocker les retours sur les suppressions de comptes
CREATE TABLE IF NOT EXISTS public.delete_account_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid, -- Stocké sans clé étrangère CASCADE pour conserver l'historique après suppression
  phone_number text,
  email text,
  reason text NOT NULL,
  feedback text,
  created_at timestamp with time zone DEFAULT now()
);

-- RLS (Row Level Security)
ALTER TABLE public.delete_account_feedback ENABLE ROW LEVEL SECURITY;

-- Seuls les administrateurs peuvent lire les retours de suppression
CREATE POLICY "Allow admin read access to delete feedback"
  ON public.delete_account_feedback FOR SELECT
  TO authenticated
  USING ((SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true);

-- Autoriser l'insertion de retours
CREATE POLICY "Allow authenticated inserts to delete feedback"
  ON public.delete_account_feedback FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Forcer le rechargement du schéma
NOTIFY pgrst, 'reload schema';
