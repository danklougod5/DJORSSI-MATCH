-- Table to track MoyaPay transactions
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    pay_token TEXT UNIQUE NOT NULL,
    amount NUMERIC NOT NULL,
    currency TEXT DEFAULT 'XOF',
    gateway TEXT DEFAULT 'WAVE_CI',
    status TEXT DEFAULT 'PENDING', -- PENDING, SUCCESS, FAILED
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS for payments
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Users can view their own payments
CREATE POLICY "Users can view own payments" ON public.payments FOR SELECT USING (auth.uid() = user_id);

-- Admin (internal/service) can update payments
-- For simplicity in this dev environment, we'll allow service_role or a specific policy if needed.
-- But since webhooks will use the service_role or API with enough privs, we're good.
