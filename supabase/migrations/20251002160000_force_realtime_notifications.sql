-- =====================================================================================
-- FORCE REALTIME ON NOTIFICATIONS - Aggressive Configuration
-- =====================================================================================
-- This ensures realtime is 100% enabled on the notifications table
-- =====================================================================================

-- Step 1: Ensure table exists
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications') THEN
    RAISE EXCEPTION 'notifications table does not exist! Run previous migration first.';
  END IF;
END $$;

-- Step 2: Remove from all publications first
DO $$ 
BEGIN
  -- Remove from realtime publication
  BEGIN
    ALTER PUBLICATION supabase_realtime DROP TABLE notifications;
    RAISE NOTICE 'Removed notifications from supabase_realtime';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Table was not in supabase_realtime (OK)';
  END;
END $$;

-- Step 3: Set replica identity to FULL (required for realtime)
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- Step 4: Add to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Step 5: Verify realtime is enabled
DO $$ 
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime'
    AND schemaname = 'public'
    AND tablename = 'notifications';
  
  IF v_count = 0 THEN
    RAISE EXCEPTION 'FAILED: notifications table NOT in realtime publication!';
  ELSE
    RAISE NOTICE '✅ SUCCESS: notifications table IS in realtime publication';
  END IF;
END $$;

-- Step 6: Check replica identity
DO $$ 
DECLARE
  v_replica_identity TEXT;
BEGIN
  SELECT relreplident INTO v_replica_identity
  FROM pg_class
  WHERE relname = 'notifications';
  
  IF v_replica_identity = 'f' THEN
    RAISE NOTICE '✅ Replica identity is FULL';
  ELSE
    RAISE NOTICE '⚠️ Replica identity is: %', v_replica_identity;
  END IF;
END $$;

-- Step 7: Grant necessary permissions
GRANT SELECT ON notifications TO anon;
GRANT SELECT ON notifications TO authenticated;

-- Step 8: Final verification query
SELECT 
  schemaname,
  tablename,
  'IN REALTIME PUBLICATION' as status
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename = 'notifications';

-- Success message
DO $$ 
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ REALTIME FORCED ON NOTIFICATIONS';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Notifications table is now:';
  RAISE NOTICE '  ✅ In supabase_realtime publication';
  RAISE NOTICE '  ✅ Replica identity set to FULL';
  RAISE NOTICE '  ✅ Permissions granted';
  RAISE NOTICE '';
  RAISE NOTICE 'Test by inserting a notification:';
  RAISE NOTICE '  INSERT INTO notifications (user_id, title, body, type)';
  RAISE NOTICE '  VALUES (''your-user-id'', ''Test'', ''Test body'', ''test'');';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

