-- =====================================================================================
-- CREATE SUPABASE AUTH ACCOUNTS FOR TEST USERS
-- =====================================================================================
-- This migration creates Supabase Auth accounts for test users so they can login
-- Uses the same deterministic password generation as the app
-- =====================================================================================

-- Note: Supabase doesn't allow direct SQL inserts into auth.users
-- We need to use the Admin API or create a helper function
-- This migration provides SQL to check and document the accounts

-- Function to generate deterministic password (matching app logic)
CREATE OR REPLACE FUNCTION generate_test_user_password(phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  clean_phone TEXT;
  hash INTEGER := 0;
  i INTEGER;
BEGIN
  -- Remove + and any non-digits
  clean_phone := regexp_replace(phone, '[^0-9]', '', 'g');
  
  -- Create hash by summing character codes (matching Dart logic)
  FOR i IN 1..length(clean_phone) LOOP
    hash := hash + ascii(substring(clean_phone FROM i FOR 1));
  END LOOP;
  
  -- Return deterministic password
  RETURN 'whatsapp_auth_' || abs(hash)::TEXT;
END;
$$;

-- Function to generate email from phone (matching app logic)
CREATE OR REPLACE FUNCTION generate_test_user_email(phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  clean_phone TEXT;
BEGIN
  -- Remove + and any non-digits
  clean_phone := regexp_replace(phone, '[^0-9]', '', 'g');
  
  -- Return email format
  RETURN clean_phone || '@hur.delivery';
END;
$$;

-- View to show test users and their auth credentials
CREATE OR REPLACE VIEW test_user_auth_info AS
SELECT 
  u.id,
  u.name,
  u.phone,
  u.role,
  generate_test_user_email(u.phone) as auth_email,
  generate_test_user_password(u.phone) as auth_password,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM auth.users 
      WHERE email = generate_test_user_email(u.phone)
    ) THEN '✅ Auth account exists'
    ELSE '❌ Auth account missing'
  END as auth_status
FROM users u
WHERE u.phone LIKE '+964999%'
ORDER BY u.phone;

-- Grant permissions
GRANT SELECT ON test_user_auth_info TO authenticated, anon;

-- Display test user info
SELECT 
  name,
  phone,
  role,
  auth_email,
  auth_password,
  auth_status
FROM test_user_auth_info
ORDER BY phone;

-- =====================================================================================
-- MANUAL CREATION INSTRUCTIONS
-- =====================================================================================
-- Since Supabase doesn't allow direct SQL inserts into auth.users,
-- you need to create auth accounts manually or via Admin API
--
-- Option 1: Use Supabase Dashboard (Recommended)
-- 1. Go to: Supabase Dashboard → Authentication → Users
-- 2. For each test user, click "Add user"
-- 3. Use the credentials from the view above:
--    - Email: (from auth_email column)
--    - Password: (from auth_password column)
--    - Auto Confirm: ✅ Check
--
-- Option 2: Use Supabase Admin API (Programmatic)
-- Create a script or use the Supabase Management API to create users
--
-- Option 3: Let the app create them (Easiest)
-- When test users login via OTP, the app will automatically create
-- auth accounts with the correct credentials
-- =====================================================================================

-- Success message
DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TEST USER AUTH HELPER FUNCTIONS CREATED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'View test user credentials:';
  RAISE NOTICE '  SELECT * FROM test_user_auth_info;';
  RAISE NOTICE '';
  RAISE NOTICE 'Auth accounts will be created automatically';
  RAISE NOTICE 'when test users login via OTP in the app.';
  RAISE NOTICE '';
  RAISE NOTICE 'Or create them manually in Supabase Dashboard:';
  RAISE NOTICE '  Authentication → Users → Add user';
  RAISE NOTICE '  Use email and password from test_user_auth_info view';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

