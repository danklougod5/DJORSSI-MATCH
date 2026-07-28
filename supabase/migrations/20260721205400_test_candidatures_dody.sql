-- Temporarily disable swipe limit trigger, insert test data, then re-enable
ALTER TABLE public.swipes_log DISABLE TRIGGER enforce_swipe_limit;

INSERT INTO public.swipes_log (user_id, job_id, direction)
VALUES 
  ('ac53db77-5ad5-4d20-8527-64b4386d76dd', '5f8132f9-6262-4431-b4b7-2100d4fbca23', 'right'),
  ('41eacdf3-c6b8-45ed-add8-675fa9576a07', '5f8132f9-6262-4431-b4b7-2100d4fbca23', 'right'),
  ('dc108f4e-7fd1-4484-a465-8feefcc3217f', '5f8132f9-6262-4431-b4b7-2100d4fbca23', 'right')
ON CONFLICT DO NOTHING;

ALTER TABLE public.swipes_log ENABLE TRIGGER enforce_swipe_limit;
