-- 1. Add DELETE policy for profiles
CREATE POLICY "Users can delete own profile" ON public.profiles
    FOR DELETE USING (auth.uid() = id);

-- 2. Add DELETE policy for applications
CREATE POLICY "Users can delete own applications" ON public.applications
    FOR DELETE USING (auth.uid() = candidate_id);

-- 3. Add DELETE policy for swipes_log
CREATE POLICY "Users can delete own swipes" ON public.swipes_log
    FOR DELETE USING (auth.uid() = user_id);

-- 4. Update profiles foreign key to cascade on delete from auth.users
-- First, find the constraint name (usually profiles_id_fkey)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'profiles_id_fkey') THEN
        ALTER TABLE public.profiles DROP CONSTRAINT profiles_id_fkey;
    END IF;
END $$;

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_id_fkey
    FOREIGN KEY (id)
    REFERENCES auth.users(id)
    ON DELETE CASCADE;
