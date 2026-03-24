-- Migration to protect sensitive profile columns - 20260323000000
-- This ensures users cannot elevate their own privileges

-- 1. Create a function to protect is_admin and is_premium columns
CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if is_admin or is_premium is being changed
    IF (NEW.is_admin IS DISTINCT FROM OLD.is_admin OR NEW.is_premium IS DISTINCT FROM OLD.is_premium) THEN
        -- Only allow the change if the current user is an admin OR it's a service_role
        -- Note: auth.uid() returns the user's ID, auth.role() returns the role
        
        -- If it's a normal authenticated user trying to change their own role, reject the change for those columns
        IF auth.role() = 'authenticated' AND (
            NOT EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE id = auth.uid() AND is_admin = true
            )
        ) THEN
            -- Revert the sensitive columns to their old values
            NEW.is_admin = OLD.is_admin;
            NEW.is_premium = OLD.is_premium;
            
            -- Optional: Log an alert or raise a notice
            -- RAISE NOTICE 'Tentative de changement de privilèges bloquée pour l''utilisateur %', auth.uid();
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Attach the trigger to the profiles table
DROP TRIGGER IF EXISTS on_profile_update_protect_sensitive_columns ON public.profiles;
CREATE TRIGGER on_profile_update_protect_sensitive_columns
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_profile_sensitive_columns();

-- 3. Update RLS to be more explicit (Optional but good practice)
-- We keep the existing policy "Users can update own profile" but the trigger now handles the field-level security.

-- 4. Secure the 'feedbacks' and 'unsubscriptions' viewing policies
-- Currently they use a subquery that could be slow or problematic.
-- Let's make sure the check is robust.

-- Feedback policy reinforcement
DROP POLICY IF EXISTS "Admins can view all feedbacks" ON public.feedbacks;
CREATE POLICY "Admins can view all feedbacks" ON public.feedbacks 
  FOR SELECT USING (
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
  );

-- Unsubscriptions policy reinforcement
DROP POLICY IF EXISTS "Admins can view all unsubscriptions" ON public.unsubscriptions;
CREATE POLICY "Admins can view all unsubscriptions" ON public.unsubscriptions 
  FOR SELECT USING (
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
  );

-- Admin Dashboard access to stats/jobs
-- Let's ensure admins can manage jobs
DROP POLICY IF EXISTS "Admins can manage jobs" ON public.jobs;
CREATE POLICY "Admins can manage jobs" ON public.jobs
  FOR ALL USING (
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
  );
