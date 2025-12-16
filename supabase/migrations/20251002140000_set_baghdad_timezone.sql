-- =====================================================================================
-- SET BAGHDAD TIMEZONE (GMT+3)
-- =====================================================================================
-- Ensures all database timestamps use Baghdad timezone consistently
-- This fixes timezone mismatches between database and frontend
-- =====================================================================================

-- Set session timezone to Baghdad (GMT+3)
ALTER DATABASE postgres SET timezone TO 'Asia/Baghdad';

-- Set current session timezone
SET timezone TO 'Asia/Baghdad';

-- Verify timezone setting
DO $$ 
DECLARE
  v_timezone TEXT;
BEGIN
  SELECT current_setting('TIMEZONE') INTO v_timezone;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TIMEZONE CONFIGURATION';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Database timezone set to: %', v_timezone;
  RAISE NOTICE 'This is Baghdad time (GMT+3)';
  RAISE NOTICE '';
  RAISE NOTICE 'Current database time: %', NOW();
  RAISE NOTICE 'Current UTC time: %', NOW() AT TIME ZONE 'UTC';
  RAISE NOTICE '';
  RAISE NOTICE '✅ All new timestamps will use Baghdad timezone';
  RAISE NOTICE '✅ Existing timestamps stored as UTC (unchanged)';
  RAISE NOTICE '✅ Frontend will parse times correctly';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

-- Add helpful comment
COMMENT ON DATABASE postgres IS 
  'Timezone set to Asia/Baghdad (GMT+3) for Iraq delivery app';

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- 
-- How Timestamps Work:
-- 1. All timestamps are stored as UTC in database (PostgreSQL standard)
-- 2. timezone setting controls how NOW() interprets current time
-- 3. When client reads timestamps, they're in UTC
-- 4. Client must convert to local timezone for display
--
-- Frontend Handling:
-- - Parse timestamps with .toUtc() for consistency
-- - Compare times in UTC
-- - Display to user in local time (Baghdad = UTC+3)
--
-- =====================================================================================

