-- Create function to send FCM notification when new notification is inserted
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
    PERFORM
      net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/send-push-notification',
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
          'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
          'user_id', NEW.user_id,
          'title', NEW.title,
          'body', NEW.body,
          'data', COALESCE(NEW.data, '{}'::jsonb)
        )
      );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on notifications table
DROP TRIGGER IF EXISTS notifications_fcm_trigger ON notifications;
CREATE TRIGGER notifications_fcm_trigger
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION send_notification_via_fcm();

-- Set required settings (these should be set in Supabase dashboard)
-- ALTER SYSTEM SET app.settings.supabase_url = 'https://bvtoxmmiitznagsbubhg.supabase.co';
-- ALTER SYSTEM SET app.settings.service_role_key = 'your_service_role_key_here';
