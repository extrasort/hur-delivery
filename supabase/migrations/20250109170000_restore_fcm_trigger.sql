-- =====================================================================================
-- RESTORE FCM TRIGGER FUNCTION
-- =====================================================================================
-- This migration restores the missing FCM trigger function that sends push notifications
-- when notifications are inserted into the database
-- =====================================================================================

-- =====================================================================================
-- 1. CREATE FCM TRIGGER FUNCTION
-- =====================================================================================

CREATE OR REPLACE FUNCTION send_notification_via_fcm()
RETURNS TRIGGER AS $$
DECLARE
  fcm_token TEXT;
  platform_type TEXT;
BEGIN
  -- Get the FCM token for the user
  SELECT fcm_token, platform INTO fcm_token, platform_type
  FROM user_fcm_tokens 
  WHERE user_id = NEW.user_id 
  ORDER BY updated_at DESC 
  LIMIT 1;
  
  -- If FCM token exists, trigger the Edge Function
  IF fcm_token IS NOT NULL THEN
    -- Call the Edge Function to send FCM notification
    BEGIN
      PERFORM
        net.http_post(
          url := 'https://bvtoxmmiitznagsbubhg.supabase.co/functions/v1/send-push-notification',
          headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjA3OTkxNywiZXhwIjoyMDY3NjU1OTE3fQ.wKOQiltkUnYiZY1LRRkJcZ_8lL7WZZgmpDdHVoDRqqE',
            'Content-Type', 'application/json'
          ),
          body := jsonb_build_object(
            'user_id', NEW.user_id,
            'title', NEW.title,
            'body', NEW.body,
            'data', COALESCE(NEW.data, '{}'::jsonb)
          )
        );
      
      -- Log success
      RAISE NOTICE 'FCM notification sent for user: %', NEW.user_id;
      
    EXCEPTION WHEN OTHERS THEN
      -- Log error but don't fail the transaction
      RAISE NOTICE 'FCM notification failed for user %: %', NEW.user_id, SQLERRM;
    END;
  ELSE
    -- Log when no FCM token found
    RAISE NOTICE 'No FCM token found for user: %', NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- 2. CREATE TRIGGER ON NOTIFICATIONS TABLE
-- =====================================================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS notifications_fcm_trigger ON notifications;

-- Create the trigger
CREATE TRIGGER notifications_fcm_trigger
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION send_notification_via_fcm();

-- =====================================================================================
-- 3. COMMENT ON FUNCTION
-- =====================================================================================

COMMENT ON FUNCTION send_notification_via_fcm() IS 
  'Sends FCM push notifications when new notifications are inserted into the database';

-- =====================================================================================
-- 4. VERIFY FUNCTION AND TRIGGER CREATION
-- =====================================================================================

-- Check if function exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'send_notification_via_fcm') THEN
    RAISE NOTICE '✅ FCM trigger function created successfully';
  ELSE
    RAISE NOTICE '❌ FCM trigger function creation failed';
  END IF;
END $$;

-- Check if trigger exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'notifications_fcm_trigger') THEN
    RAISE NOTICE '✅ FCM trigger created successfully';
  ELSE
    RAISE NOTICE '❌ FCM trigger creation failed';
  END IF;
END $$;

-- =====================================================================================
-- END OF MIGRATION
-- =====================================================================================
