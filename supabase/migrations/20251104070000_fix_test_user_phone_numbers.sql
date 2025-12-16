-- =====================================================================================
-- FIX TEST USER PHONE NUMBERS - Add missing zero
-- =====================================================================================
-- Updates existing test users to have correct phone format (+9649990000001 instead of +964999000001)
-- =====================================================================================

-- Delete old test users with wrong phone format
DELETE FROM users WHERE phone IN (
  '+964999000001',
  '+964999000002',
  '+964999000003',
  '+964999000004',
  '+964999000005',
  '+964999000006'
);

-- Delete auth accounts for old phone numbers
-- Note: This will delete auth accounts, they will be recreated by the script
DO $$
DECLARE
  old_email TEXT;
  old_phones TEXT[] := ARRAY[
    '964999000001',
    '964999000002',
    '964999000003',
    '964999000004',
    '964999000005',
    '964999000006'
  ];
BEGIN
  FOREACH old_email IN ARRAY old_phones
  LOOP
    -- Delete auth user if exists
    DELETE FROM auth.users WHERE email = (old_email || '@hur.delivery');
  END LOOP;
END $$;

-- Recreate test users with correct phone format
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
) ON CONFLICT (phone) DO UPDATE SET updated_at = NOW();

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
) ON CONFLICT (phone) DO UPDATE SET updated_at = NOW();

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
  33.3152,
  44.3661,
  NOW()
) ON CONFLICT (phone) DO UPDATE SET updated_at = NOW();

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
  33.3200,
  44.3700,
  NOW()
) ON CONFLICT (phone) DO UPDATE SET updated_at = NOW();

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
  33.3500,
  44.4000,
  NOW()
) ON CONFLICT (phone) DO UPDATE SET updated_at = NOW();

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
  FALSE,
  TRUE,
  33.3150,
  44.3650,
  NOW()
) ON CONFLICT (phone) DO UPDATE SET updated_at = NOW();

-- Verify test users
SELECT 
  name,
  phone,
  role,
  CASE WHEN role = 'driver' THEN is_online ELSE NULL END as online,
  '✅ Correct Format' as status
FROM users
WHERE phone LIKE '+96499900000%'
ORDER BY phone;

DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TEST USER PHONE NUMBERS FIXED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Updated phone numbers:';
  RAISE NOTICE '  Admin: +9649990000001';
  RAISE NOTICE '  Merchant: +9649990000002';
  RAISE NOTICE '  Driver 1: +9649990000003';
  RAISE NOTICE '  Driver 2: +9649990000004';
  RAISE NOTICE '  Driver 3: +9649990000005';
  RAISE NOTICE '  Driver 4: +9649990000006 (offline)';
  RAISE NOTICE '';
  RAISE NOTICE 'Next step: Run the auth creation script again';
  RAISE NOTICE '  node scripts/create_test_auth_users.js';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

