-- Insert a job alert directly for Dody to bypass RLS via migration
INSERT INTO public.job_alerts (user_id, sectors, is_active, created_at, updated_at)
VALUES (
  'c43f3caf-7f1d-4882-93c6-e7c4e778de36', 
  ARRAY['Informatique , Télécoms', 'Informatique'], 
  true, 
  now(), 
  now()
)
ON CONFLICT (user_id) 
DO UPDATE SET 
  sectors = ARRAY['Informatique , Télécoms', 'Informatique'], 
  is_active = true, 
  updated_at = now();
