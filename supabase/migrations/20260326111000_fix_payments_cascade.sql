-- Fix foreign key constraint on payments table to allow cascading delete from auth.users
-- This resolves the "Database error deleting user" when a user tries to delete their account

DO $$
BEGIN
    -- 1. Check if the constraint exists and drop it if necessary
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'payments' AND table_schema = 'public' AND constraint_type = 'FOREIGN KEY'
    ) THEN
        -- We drop the first FK referencing auth.users on that column
        -- (Usually it's payments_user_id_fkey by default)
        ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_user_id_fkey;
    END IF;
END $$;

-- 2. Add the constraint back with ON DELETE CASCADE
ALTER TABLE public.payments
    ADD CONSTRAINT payments_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users(id)
    ON DELETE CASCADE;
