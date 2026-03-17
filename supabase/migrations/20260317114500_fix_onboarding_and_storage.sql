-- 1. Ajout de la politique INSERT manquante pour les profils
-- Sans cela, l'upsert échoue lors de la création d'un nouveau compte
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 2. Création du bucket de stockage pour les CV s'il n'existe pas
INSERT INTO storage.buckets (id, name, public)
VALUES ('cv_files', 'cv_files', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Politiques RLS pour le stockage des CV (cv_files)
-- Permettre aux utilisateurs authentifiés d'uploader des fichiers
CREATE POLICY "Allow authenticated uploads" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'cv_files');

-- Permettre aux utilisateurs de mettre à jour leurs propres fichiers
CREATE POLICY "Allow individual updates" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'cv_files' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Permettre la lecture publique (pour l'envoi d'e-mails)
CREATE POLICY "Allow public read" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'cv_files');

-- Permettre la suppression par l'utilisateur
CREATE POLICY "Allow individual deletes" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'cv_files' AND auth.uid()::text = (storage.foldername(name))[1]);
