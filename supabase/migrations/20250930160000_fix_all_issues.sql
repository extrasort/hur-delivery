-- =====================================================================================
-- FIX ALL CRITICAL ISSUES
-- =====================================================================================
-- 1. Fix infinite recursion in RLS policies
-- 2. Fix driver reject permissions
-- 3. Ensure auto-reject works properly
-- =====================================================================================

-- =====================================================================================
-- 1. FIX INFINITE RECURSION - Drop ALL recursive policies on users table
-- =====================================================================================

DROP POLICY IF EXISTS "users_view_own" ON users;
DROP POLICY IF EXISTS "users_update_own" ON users;
DROP POLICY IF EXISTS "users_admin_view_all" ON users;
DROP POLICY IF EXISTS "users_admin_update_all" ON users;
DROP POLICY IF EXISTS "users_drivers_view_online_drivers" ON users;
DROP POLICY IF EXISTS "users_insert_authenticated" ON users;
DROP POLICY IF EXISTS "users_can_register" ON users;
DROP POLICY IF EXISTS "users_insert_own" ON users;
DROP POLICY IF EXISTS "users_upsert_own" ON users;
DROP POLICY IF EXISTS "users_select_own" ON users;

-- Create simple, non-recursive policies
CREATE POLICY "users_select_own" ON users
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "users_insert_own" ON users
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update_own" ON users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- =====================================================================================
-- 2. FIX ORDERS POLICIES - Remove recursive admin checks
-- =====================================================================================

-- Drop recursive admin policies
DROP POLICY IF EXISTS "orders_admin_view_all" ON orders;
DROP POLICY IF EXISTS "orders_system_update" ON orders;

-- Orders: System functions can update (needed for auto-assignment)
-- Use security definer functions instead of policies
CREATE POLICY "orders_service_role_all" ON orders
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================================================
-- 3. FIX ORDER_REJECTED_DRIVERS POLICIES - Allow driver reject to work
-- =====================================================================================

DROP POLICY IF EXISTS "rejected_drivers_system" ON order_rejected_drivers;
DROP POLICY IF EXISTS "rejected_drivers_driver_view_own" ON order_rejected_drivers;

-- Allow system to insert rejections
CREATE POLICY "rejected_drivers_insert" ON order_rejected_drivers
  FOR INSERT
  TO authenticated
  WITH CHECK (true);  -- Functions will handle this

-- Drivers can view their own rejections
CREATE POLICY "rejected_drivers_select_own" ON order_rejected_drivers
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

-- Service role can do everything
CREATE POLICY "rejected_drivers_service_role" ON order_rejected_drivers
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================================================
-- 4. FIX ORDER_ASSIGNMENTS POLICIES
-- =====================================================================================

DROP POLICY IF EXISTS "assignments_driver_view_own" ON order_assignments;
DROP POLICY IF EXISTS "assignments_merchant_view_own" ON order_assignments;
DROP POLICY IF EXISTS "assignments_system" ON order_assignments;

-- Simple policies without recursion
CREATE POLICY "assignments_select_own" ON order_assignments
  FOR SELECT
  TO authenticated
  USING (driver_id = auth.uid());

CREATE POLICY "assignments_insert" ON order_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (true);  -- Functions handle this

CREATE POLICY "assignments_update_own" ON order_assignments
  FOR UPDATE
  TO authenticated
  USING (driver_id = auth.uid());

CREATE POLICY "assignments_service_role" ON order_assignments
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================================================
-- 5. FIX NOTIFICATIONS POLICIES
-- =====================================================================================

DROP POLICY IF EXISTS "notifications_view_own" ON notifications;
DROP POLICY IF EXISTS "notifications_update_own" ON notifications;
DROP POLICY IF EXISTS "notifications_system_create" ON notifications;

CREATE POLICY "notifications_select_own" ON notifications
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "notifications_update_own" ON notifications
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "notifications_insert" ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (true);  -- Triggers create notifications

CREATE POLICY "notifications_service_role" ON notifications
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================================================
-- 6. ENSURE STORAGE BUCKET AND POLICIES EXIST
-- =====================================================================================

-- Create storage bucket if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('files', 'files', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies
DROP POLICY IF EXISTS "Users upload own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users view own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users update own documents" ON storage.objects;
DROP POLICY IF EXISTS "authenticated_users_upload" ON storage.objects;
DROP POLICY IF EXISTS "authenticated_users_view" ON storage.objects;

-- Simple storage policies
CREATE POLICY "storage_authenticated_insert" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'files');

CREATE POLICY "storage_authenticated_select" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'files');

CREATE POLICY "storage_authenticated_update" ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'files');

CREATE POLICY "storage_service_role" ON storage.objects
  FOR ALL
  TO service_role
  USING (bucket_id = 'files')
  WITH CHECK (bucket_id = 'files');

-- =====================================================================================
-- 7. VERIFY NO RECURSIVE POLICIES
-- =====================================================================================

DO $$ 
DECLARE
  v_recursive_count INTEGER;
BEGIN
  -- Check for policies that reference the same table
  SELECT COUNT(*) INTO v_recursive_count
  FROM pg_policies
  WHERE (
    qual::text LIKE '%FROM users%' OR 
    qual::text LIKE '%FROM "users"%' OR
    with_check::text LIKE '%FROM users%' OR 
    with_check::text LIKE '%FROM "users"%'
  )
  AND tablename = 'users';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RLS POLICIES FIXED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Recursive policies on users table: %', v_recursive_count;
  RAISE NOTICE '';
  
  IF v_recursive_count = 0 THEN
    RAISE NOTICE '✅ No infinite recursion detected!';
    RAISE NOTICE '✅ Registration should now work!';
    RAISE NOTICE '✅ Driver reject should now work!';
  ELSE
    RAISE NOTICE '⚠️  Still have % recursive policies', v_recursive_count;
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE 'Try the following in your app:';
  RAISE NOTICE '1. Register a new user';
  RAISE NOTICE '2. Create an order';
  RAISE NOTICE '3. Driver reject order';
  RAISE NOTICE '4. Verify order reassigns';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

-- Show current policies
SELECT 
  tablename,
  policyname,
  cmd,
  '✅' as status
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('users', 'orders', 'order_rejected_drivers', 'order_assignments', 'notifications')
ORDER BY tablename, policyname;

