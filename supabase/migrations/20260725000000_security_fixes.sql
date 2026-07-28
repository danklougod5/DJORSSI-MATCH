-- Migration de Sécurité Globale — 20260725000000_security_fixes.sql
-- Correctif cumulatif pour verrouiller les vulnérabilités RLS, RPC et Privilèges

-- 1. CORRECTION SUR PROFILES : Restreindre l'UPDATE à son propre profil ou admin
DROP POLICY IF EXISTS "Enable update for users and admin" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

CREATE POLICY "Users can update own profile or admin"
ON public.profiles
FOR UPDATE
USING (
  auth.uid() = id OR 
  (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
)
WITH CHECK (
  auth.uid() = id OR 
  (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
);

-- 2. ETENDRE LE TRIGGER DE PROTECTION SUR PROFILES
CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Empêcher la modification non-autorisée des colonnes sensibles de privilèges ou rôles
    IF (
        NEW.is_admin IS DISTINCT FROM OLD.is_admin OR 
        NEW.is_premium IS DISTINCT FROM OLD.is_premium OR
        NEW.is_recruiter IS DISTINCT FROM OLD.is_recruiter OR
        NEW.is_blocked IS DISTINCT FROM OLD.is_blocked
    ) THEN
        IF auth.role() = 'authenticated' AND (
            NOT EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE id = auth.uid() AND is_admin = true
            )
        ) THEN
            -- Restituer les anciennes valeurs des colonnes sensibles
            NEW.is_admin = OLD.is_admin;
            NEW.is_premium = OLD.is_premium;
            NEW.is_recruiter = OLD.is_recruiter;
            NEW.is_blocked = OLD.is_blocked;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. CORRECTION SUR RECRUITER_CANDIDATE_CHATS ET CHAT_MESSAGES
DROP POLICY IF EXISTS "Users and admins can view chats" ON public.recruiter_candidate_chats;
DROP POLICY IF EXISTS "Users can view chats they are part of" ON public.recruiter_candidate_chats;

CREATE POLICY "Users and admins can view chats"
ON public.recruiter_candidate_chats
FOR SELECT
USING (
  auth.uid() = recruiter_id OR 
  auth.uid() = candidate_id OR 
  (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
);

DROP POLICY IF EXISTS "Users and admins can view chat messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can view messages in their chats" ON public.chat_messages;

CREATE POLICY "Users and admins can view chat messages"
ON public.chat_messages
FOR SELECT
USING (
  EXISTS (
      SELECT 1 FROM public.recruiter_candidate_chats
      WHERE id = chat_messages.chat_id
      AND (recruiter_id = auth.uid() OR candidate_id = auth.uid())
  ) OR (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
);

-- 4. CORRECTION SUR SUPPORT_MESSAGES
DROP POLICY IF EXISTS "Anyone or admin can view support messages" ON public.support_messages;
DROP POLICY IF EXISTS "Admins can view all support messages" ON public.support_messages;
DROP POLICY IF EXISTS "Users can view their own support messages" ON public.support_messages;

CREATE POLICY "Users and admin can view support messages"
ON public.support_messages
FOR SELECT
USING (
  auth.uid() = user_id OR 
  (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
);

-- 5. CORRECTION SUR JOB_REPORTS
DROP POLICY IF EXISTS "Admins can manage reports" ON public.job_reports;

CREATE POLICY "Admins can manage reports"
ON public.job_reports
FOR ALL
USING (
  (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
)
WITH CHECK (
  (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
);

-- 6. SÉCURISATION DE LA FONCTION RPC save_candidate_parsed_cv
CREATE OR REPLACE FUNCTION save_candidate_parsed_cv(
  p_candidate_id TEXT,
  p_cv_data JSONB,
  p_title TEXT DEFAULT 'CV Importé'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uuid UUID;
BEGIN
  v_uuid := p_candidate_id::UUID;

  -- Vérification d'autorisation
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non autorisé';
  END IF;

  IF auth.uid() <> v_uuid 
     AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND (is_recruiter = true OR is_admin = true)) THEN
    RAISE EXCEPTION 'Accès refusé pour modifier ce CV';
  END IF;

  IF EXISTS (SELECT 1 FROM user_cvs WHERE user_id = v_uuid) THEN
    UPDATE user_cvs
    SET cv_data = p_cv_data,
        title = COALESCE(NULLIF(p_title, ''), 'CV Importé'),
        updated_at = NOW()
    WHERE user_id = v_uuid;
  ELSE
    INSERT INTO user_cvs (user_id, title, cv_data, template_id, primary_color, secondary_color, updated_at)
    VALUES (
      v_uuid,
      COALESCE(NULLIF(p_title, ''), 'CV Importé'),
      p_cv_data,
      'classic',
      '#1E3A8A',
      '#4B5563',
      NOW()
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION save_candidate_parsed_cv(
  p_candidate_id UUID,
  p_cv_data JSONB,
  p_title TEXT DEFAULT 'CV Importé'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM save_candidate_parsed_cv(p_candidate_id::TEXT, p_cv_data, p_title);
END;
$$;

-- 7. CORRECTION DES POLITIQUES SUR JOBS
DROP POLICY IF EXISTS "Allow scraper to insert jobs" ON public.jobs;
DROP POLICY IF EXISTS "Allow scraper to update jobs" ON public.jobs;

CREATE POLICY "Authenticated users and recruiters can insert jobs"
ON public.jobs
FOR INSERT
WITH CHECK (
  auth.uid() IS NOT NULL OR
  (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
);

CREATE POLICY "Recruiters and admins can update own jobs"
ON public.jobs
FOR UPDATE
USING (
  jobs.recruiter_id = auth.uid() OR
  (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
);

-- 8. CORRECTION DES POLITIQUES SUR STORAGE (cv_files)
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;

CREATE POLICY "Allow individual uploads" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'cv_files' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

NOTIFY pgrst, 'reload schema';
