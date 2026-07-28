-- Migration to allow saving parsed candidate CV data securely via RPC (bypasses RLS for recruiters caching CVs)

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

-- Also support UUID version in case PostgREST maps it as UUID
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

GRANT EXECUTE ON FUNCTION save_candidate_parsed_cv(TEXT, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION save_candidate_parsed_cv(TEXT, JSONB, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION save_candidate_parsed_cv(UUID, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION save_candidate_parsed_cv(UUID, JSONB, TEXT) TO anon;

NOTIFY pgrst, 'reload schema';
