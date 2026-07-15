-- Migration: Add description and metadata columns to payments table
-- This allows tracking the purpose and extra context of payments.

ALTER TABLE public.payments
ADD COLUMN IF NOT EXISTS description TEXT,
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Comment on columns
COMMENT ON COLUMN public.payments.description IS 'Description of the purchase (e.g. Abonnement Djorssi Premium, Modification de CV)';
COMMENT ON COLUMN public.payments.metadata IS 'Metadata associated with the payment (e.g. {type: extra_cv})';
