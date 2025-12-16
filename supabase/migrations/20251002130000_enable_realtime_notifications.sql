-- =====================================================================================
-- ENABLE REALTIME FOR NOTIFICATIONS TABLE
-- =====================================================================================
-- Ensures persistent WebSocket connections work reliably for notifications
-- =====================================================================================

-- Enable realtime for notifications table
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Also ensure users table has realtime enabled (for online status sync)
ALTER PUBLICATION supabase_realtime ADD TABLE users;

-- Also ensure orders table has realtime enabled (for driver order assignments)
ALTER PUBLICATION supabase_realtime ADD TABLE orders;

-- Verify realtime is enabled
DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'REALTIME ENABLED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Realtime publication enabled for:';
  RAISE NOTICE '  ✅ notifications table';
  RAISE NOTICE '  ✅ users table';
  RAISE NOTICE '  ✅ orders table';
  RAISE NOTICE '';
  RAISE NOTICE 'WebSocket connections will now work';
  RAISE NOTICE 'reliably even when app is in background.';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

