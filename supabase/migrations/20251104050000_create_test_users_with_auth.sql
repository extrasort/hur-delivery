-- =====================================================================================
-- CREATE TEST USERS WITH SUPABASE AUTH ACCOUNTS
-- =====================================================================================
-- This migration creates test users that can login via OTP in the app
-- The app will automatically create Supabase Auth accounts when they login
-- This migration just ensures the database users exist
-- =====================================================================================

-- Clean up any existing test data
DELETE FROM users WHERE phone LIKE '+964999%';

-- Create Test Admin
INSERT INTO users (
  id, phone, name, role, manual_verified, is_active, created_at
)
VALUES (
  gen_random_uuid(),
  '+9649990000001',
  'Test Admin',
  'admin',
  TRUE,
  TRUE,
  NOW()
) ON CONFLICT (phone) DO NOTHING
RETURNING id, name, role, '✅ Admin Created' as status;

-- Create Test Merchant
INSERT INTO users (
  id, phone, name, role, store_name, manual_verified, is_active,
  address, latitude, longitude, created_at
)
VALUES (
  gen_random_uuid(),
  '+9649990000002',
  'Test Merchant',
  'merchant',
  'Test Store',
  TRUE,
  TRUE,
  'Baghdad, Karrada',
  33.3152,
  44.3661,
  NOW()
) ON CONFLICT (phone) DO NOTHING
RETURNING id, name, role, store_name, '✅ Merchant Created' as status;

-- Create Test Driver 1 (Closest)
INSERT INTO users (
  id, phone, name, role, vehicle_type, manual_verified, is_online, is_active,
  latitude, longitude, created_at
)
VALUES (
  gen_random_uuid(),
  '+9649990000003',
  'Test Driver 1 (Closest)',
  'driver',
  'Motorcycle',
  TRUE,
  TRUE,
  TRUE,
  33.3152,  -- Same location as pickup
  44.3661,
  NOW()
) ON CONFLICT (phone) DO NOTHING
RETURNING id, name, role, is_online, '✅ Driver 1 Created' as status;

-- Create Test Driver 2 (Medium distance)
INSERT INTO users (
  id, phone, name, role, vehicle_type, manual_verified, is_online, is_active,
  latitude, longitude, created_at
)
VALUES (
  gen_random_uuid(),
  '+9649990000004',
  'Test Driver 2 (Medium)',
  'driver',
  'Car',
  TRUE,
  TRUE,
  TRUE,
  33.3200,  -- ~5km away
  44.3700,
  NOW()
) ON CONFLICT (phone) DO NOTHING
RETURNING id, name, role, is_online, '✅ Driver 2 Created' as status;

-- Create Test Driver 3 (Far)
INSERT INTO users (
  id, phone, name, role, vehicle_type, manual_verified, is_online, is_active,
  latitude, longitude, created_at
)
VALUES (
  gen_random_uuid(),
  '+9649990000005',
  'Test Driver 3 (Far)',
  'driver',
  'Car',
  TRUE,
  TRUE,
  TRUE,
  33.3500,  -- ~10km away
  44.4000,
  NOW()
) ON CONFLICT (phone) DO NOTHING
RETURNING id, name, role, is_online, '✅ Driver 3 Created' as status;

-- Create Test Driver 4 (Offline - Should not receive orders)
INSERT INTO users (
  id, phone, name, role, vehicle_type, manual_verified, is_online, is_active,
  latitude, longitude, created_at
)
VALUES (
  gen_random_uuid(),
  '+9649990000006',
  'Test Driver 4 (Offline)',
  'driver',
  'Motorcycle',
  TRUE,
  FALSE,  -- OFFLINE
  TRUE,
  33.3150,  -- Very close but offline
  44.3650,
  NOW()
) ON CONFLICT (phone) DO NOTHING
RETURNING id, name, role, is_online, '✅ Driver 4 Created (Offline)' as status;

-- Verify test users
SELECT 
  name,
  phone,
  role,
  CASE WHEN role = 'driver' THEN is_online ELSE NULL END as online,
  manual_verified as verified,
  '✅ Ready for OTP Login' as status
FROM users
WHERE phone LIKE '+964999%'
ORDER BY phone;

-- =====================================================================================
-- HOW TO LOGIN WITH TEST USERS
-- =====================================================================================
-- 
-- 1. Open the Flutter app
-- 2. Enter the test phone number (e.g., +9649990000001)
-- 3. OTP will be sent via WhatsApp (via otp-handler edge function)
-- 4. Enter the OTP code
-- 5. App will automatically:
--    - Create Supabase Auth account if it doesn't exist
--    - Authenticate the user
--    - Load user profile from database
--    - Redirect to appropriate dashboard
--
-- SUPABASE AUTH ACCOUNTS:
-- - Email format: {phone}@hur.delivery (e.g., 9649990000001@hur.delivery)
-- - Password: Generated deterministically from phone number
-- - Created automatically on first login via OTP
--
-- =====================================================================================

-- Success message
DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TEST USERS CREATED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'To login with test users:';
  RAISE NOTICE '1. Open the app';
  RAISE NOTICE '2. Enter phone: +964999000001 (or any test phone)';
  RAISE NOTICE '3. Receive OTP via WhatsApp';
  RAISE NOTICE '4. Enter OTP';
  RAISE NOTICE '5. App will create auth account automatically';
  RAISE NOTICE '';
  RAISE NOTICE 'Test Users:';
  RAISE NOTICE '  Admin: +9649990000001';
  RAISE NOTICE '  Merchant: +9649990000002';
  RAISE NOTICE '  Driver 1: +9649990000003';
  RAISE NOTICE '  Driver 2: +9649990000004';
  RAISE NOTICE '  Driver 3: +9649990000005';
  RAISE NOTICE '  Driver 4: +9649990000006 (offline)';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

