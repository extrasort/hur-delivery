-- =====================================================================================
-- ENABLE REALTIME SUBSCRIPTIONS
-- =====================================================================================
-- This migration enables realtime for critical tables
-- Works even if UI Replication settings are not available
-- =====================================================================================

-- Drop existing publication for these tables (if any)
DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE orders;
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN NULL;
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE order_assignments;
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN NULL;
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE notifications;
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN NULL;
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE driver_locations;
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN NULL;
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE users;
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN NULL;
END $$;

-- Add tables to realtime publication
DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE orders;
  RAISE NOTICE '✅ Realtime enabled for orders';
EXCEPTION
  WHEN undefined_object THEN 
    RAISE NOTICE '⚠️  Publication supabase_realtime does not exist. Creating...';
    -- If publication doesn't exist, create it
    CREATE PUBLICATION supabase_realtime;
    ALTER PUBLICATION supabase_realtime ADD TABLE orders;
    RAISE NOTICE '✅ Created publication and enabled for orders';
  WHEN duplicate_object THEN
    RAISE NOTICE '✅ Realtime already enabled for orders';
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE order_assignments;
  RAISE NOTICE '✅ Realtime enabled for order_assignments';
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE '✅ Realtime already enabled for order_assignments';
  WHEN OTHERS THEN 
    RAISE NOTICE '⚠️  Could not enable realtime for order_assignments: %', SQLERRM;
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  RAISE NOTICE '✅ Realtime enabled for notifications';
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE '✅ Realtime already enabled for notifications';
  WHEN OTHERS THEN 
    RAISE NOTICE '⚠️  Could not enable realtime for notifications: %', SQLERRM;
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE driver_locations;
  RAISE NOTICE '✅ Realtime enabled for driver_locations';
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE '✅ Realtime already enabled for driver_locations';
  WHEN OTHERS THEN 
    RAISE NOTICE '⚠️  Could not enable realtime for driver_locations: %', SQLERRM;
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE users;
  RAISE NOTICE '✅ Realtime enabled for users';
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE '✅ Realtime already enabled for users';
  WHEN OTHERS THEN 
    RAISE NOTICE '⚠️  Could not enable realtime for users: %', SQLERRM;
END $$;

-- Verify realtime is enabled
DO $$ 
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime'
    AND schemaname = 'public'
    AND tablename IN ('orders', 'order_assignments', 'notifications', 'driver_locations', 'users');
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'REALTIME CONFIGURATION COMPLETE';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Tables enabled for realtime: %', v_count;
  RAISE NOTICE '';
  
  IF v_count >= 5 THEN
    RAISE NOTICE '✅ All critical tables have realtime enabled!';
    RAISE NOTICE '';
    RAISE NOTICE 'Your Flutter app will now receive:';
    RAISE NOTICE '  • Real-time order updates';
    RAISE NOTICE '  • Live assignment notifications';
    RAISE NOTICE '  • Instant status changes';
    RAISE NOTICE '  • Driver location streaming';
  ELSE
    RAISE NOTICE '⚠️  Only % of 5 tables enabled', v_count;
    RAISE NOTICE 'Some features may not work in real-time';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE 'To verify, run:';
  RAISE NOTICE '  SELECT * FROM pg_publication_tables';
  RAISE NOTICE '  WHERE pubname = ''supabase_realtime'';';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

-- Show which tables have realtime enabled
SELECT 
  schemaname,
  tablename,
  '✅ Realtime Enabled' as status
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public'
ORDER BY tablename;

