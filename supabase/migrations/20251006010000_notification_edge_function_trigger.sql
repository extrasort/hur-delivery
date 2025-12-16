-- =====================================================================================
-- NOTIFICATION EDGE FUNCTION TRIGGER
-- =====================================================================================
-- This migration creates a trigger that automatically calls the Edge Function
-- whenever a new notification is inserted into the notifications table.
-- This is a clean, centralized approach to handle all push notifications.
-- =====================================================================================

-- =====================================================================================
-- 1. DROP EXISTING TRIGGER AND FUNCTION IF EXISTS
-- =====================================================================================

DROP TRIGGER IF EXISTS trigger_send_push_notification ON notifications;
DROP FUNCTION IF EXISTS send_push_notification_on_insert();

-- =====================================================================================
-- 2. CREATE FUNCTION TO CALL EDGE FUNCTION
-- =====================================================================================

CREATE OR REPLACE FUNCTION send_push_notification_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fcm_token TEXT;
  v_platform TEXT;
  v_request_id BIGINT;
BEGIN
  -- Log the notification creation
  RAISE NOTICE 'New notification created: ID=%, User=%, Title=%', 
    NEW.id, NEW.user_id, NEW.title;

  -- Get the user's FCM token
  SELECT fcm_token, platform
  INTO v_fcm_token, v_platform
  FROM user_fcm_tokens
  WHERE user_id = NEW.user_id
  ORDER BY updated_at DESC
  LIMIT 1;

  -- If no FCM token found, log and exit
  IF v_fcm_token IS NULL THEN
    RAISE NOTICE 'No FCM token found for user %. Skipping push notification.', NEW.user_id;
    RETURN NEW;
  END IF;

  RAISE NOTICE 'Found FCM token for user %: % (platform: %)', 
    NEW.user_id, SUBSTRING(v_fcm_token, 1, 20) || '...', v_platform;

  -- Call the Edge Function using net.http_post
  BEGIN
    SELECT net.http_post(
      url := 'https://bvtoxmmiitznagsbubhg.supabase.co/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNzk5MTcsImV4cCI6MjA2NzY1NTkxN30.wVPIb4rk-8TUK_4iFf8YwvVjnTuZ1jIiQc5Ou09P7iY'
      ),
      body := jsonb_build_object(
        'user_id', NEW.user_id::text,
        'title', NEW.title,
        'body', NEW.body,
        'data', COALESCE(NEW.data, '{}'::jsonb)
      )
    ) INTO v_request_id;

    RAISE NOTICE 'Edge Function called successfully. Request ID: %', v_request_id;
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Failed to call Edge Function: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION send_push_notification_on_insert IS 
  'Automatically calls the send-push-notification Edge Function when a notification is inserted';

-- =====================================================================================
-- 3. CREATE TRIGGER ON NOTIFICATIONS TABLE
-- =====================================================================================

CREATE TRIGGER trigger_send_push_notification
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION send_push_notification_on_insert();

COMMENT ON TRIGGER trigger_send_push_notification ON notifications IS 
  'Triggers push notification via Edge Function when new notification is created';

-- =====================================================================================
-- 4. VERIFICATION
-- =====================================================================================

DO $$ 
BEGIN
  RAISE NOTICE '✅ Notification Edge Function trigger created successfully';
  RAISE NOTICE '   - Trigger: trigger_send_push_notification';
  RAISE NOTICE '   - Function: send_push_notification_on_insert()';
  RAISE NOTICE '   - Target: notifications table (AFTER INSERT)';
  RAISE NOTICE '   - Action: Calls send-push-notification Edge Function';
END $$;

