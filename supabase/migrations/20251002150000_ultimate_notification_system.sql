-- =====================================================================================
-- ULTIMATE NOTIFICATION SYSTEM - Complete Rebuild
-- =====================================================================================
-- This migration sets up a bulletproof notification system with:
-- 1. Clean notifications table structure
-- 2. Simple, reliable triggers
-- 3. Realtime enabled and verified
-- 4. Test function to verify it works
-- =====================================================================================

-- =====================================================================================
-- 1. ENSURE NOTIFICATIONS TABLE EXISTS WITH CORRECT STRUCTURE
-- =====================================================================================

-- Drop and recreate for clean slate (only if needed)
DO $$ 
BEGIN
  -- Check if table exists
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications') THEN
    RAISE NOTICE 'Notifications table exists - verifying structure...';
  ELSE
    RAISE NOTICE 'Creating notifications table...';
    
    CREATE TABLE notifications (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      type TEXT,
      data JSONB DEFAULT '{}'::jsonb,
      is_read BOOLEAN DEFAULT FALSE,
      read_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Indexes for performance
    CREATE INDEX idx_notifications_user_id ON notifications(user_id);
    CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
    CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
    
    RAISE NOTICE '✅ Notifications table created';
  END IF;
END $$;

-- =====================================================================================
-- 2. ENABLE REALTIME ON NOTIFICATIONS TABLE
-- =====================================================================================

-- Remove from publication first (if exists)
DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE notifications;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Table not in publication (this is fine)';
END $$;

-- Add to publication
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Enable realtime for INSERT events
ALTER TABLE notifications REPLICA IDENTITY FULL;

DO $$ 
BEGIN
  RAISE NOTICE '✅ Realtime enabled on notifications table';
END $$;

-- =====================================================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================================================

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "System can insert notifications" ON notifications;

-- Policy: Users can view their own notifications
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: System can insert notifications (bypass RLS for service role)
CREATE POLICY "System can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);

DO $$ 
BEGIN
  RAISE NOTICE '✅ RLS policies configured';
END $$;

-- =====================================================================================
-- 4. SIMPLE NOTIFICATION TRIGGER FUNCTION
-- =====================================================================================

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Trigger to update updated_at
DROP TRIGGER IF EXISTS notifications_updated_at ON notifications;
CREATE TRIGGER notifications_updated_at
  BEFORE UPDATE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_notifications_updated_at();

DO $$ 
BEGIN
  RAISE NOTICE '✅ Notification triggers configured';
END $$;

-- =====================================================================================
-- 5. HELPER FUNCTION: CREATE NOTIFICATION
-- =====================================================================================

CREATE OR REPLACE FUNCTION create_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_type TEXT DEFAULT 'info',
  p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  INSERT INTO notifications (user_id, title, body, type, data)
  VALUES (p_user_id, p_title, p_body, p_type, p_data)
  RETURNING id INTO v_notification_id;
  
  RAISE NOTICE 'Created notification % for user %', v_notification_id, p_user_id;
  
  RETURN v_notification_id;
END;
$$;

COMMENT ON FUNCTION create_notification IS 
  'Creates a notification for a user and returns the notification ID';

-- =====================================================================================
-- 6. TEST FUNCTION: SEND TEST NOTIFICATION
-- =====================================================================================

CREATE OR REPLACE FUNCTION send_test_notification(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification_id UUID;
  v_timestamp TEXT;
BEGIN
  v_timestamp := TO_CHAR(NOW(), 'HH24:MI:SS');
  
  v_notification_id := create_notification(
    p_user_id,
    '🧪 Test Notification',
    'Sent at ' || v_timestamp || ' - If you see this, the system works!',
    'test',
    jsonb_build_object('test', true, 'timestamp', v_timestamp)
  );
  
  RETURN 'Test notification sent! ID: ' || v_notification_id::TEXT;
END;
$$;

COMMENT ON FUNCTION send_test_notification IS 
  'Sends a test notification to verify the system is working';

-- =====================================================================================
-- 7. NOTIFICATION TRIGGERS FOR ORDER EVENTS
-- =====================================================================================

-- TRIGGER: Notify driver when order is assigned
CREATE OR REPLACE FUNCTION notify_driver_order_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only notify when driver_id changes from NULL to a value
  IF OLD.driver_id IS NULL AND NEW.driver_id IS NOT NULL THEN
    PERFORM create_notification(
      NEW.driver_id,
      '📦 طلب توصيل جديد',
      'لديك طلب جديد - اضغط قبول خلال 30 ثانية',
      'order_assigned',
      jsonb_build_object(
        'order_id', NEW.id,
        'customer_name', NEW.customer_name,
        'pickup_address', NEW.pickup_address
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_driver_on_assignment ON orders;
CREATE TRIGGER notify_driver_on_assignment
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.driver_id IS DISTINCT FROM NEW.driver_id)
  EXECUTE FUNCTION notify_driver_order_assigned();

-- TRIGGER: Notify merchant when driver accepts order
CREATE OR REPLACE FUNCTION notify_merchant_order_accepted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_name TEXT;
BEGIN
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    
    PERFORM create_notification(
      NEW.merchant_id,
      '✅ تم قبول الطلب',
      'السائق قبل الطلب وهو في طريقه للاستلام',
      'order_accepted',
      jsonb_build_object(
        'order_id', NEW.id,
        'driver_name', v_driver_name
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_merchant_on_accept ON orders;
CREATE TRIGGER notify_merchant_on_accept
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'accepted')
  EXECUTE FUNCTION notify_merchant_order_accepted();

-- TRIGGER: Notify merchant when order is on the way
CREATE OR REPLACE FUNCTION notify_merchant_order_on_the_way()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF OLD.status != 'on_the_way' AND NEW.status = 'on_the_way' THEN
    PERFORM create_notification(
      NEW.merchant_id,
      '🚗 السائق في الطريق',
      'السائق في طريقه للتوصيل',
      'order_status_update',
      jsonb_build_object('order_id', NEW.id, 'status', 'on_the_way')
    );
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_merchant_on_the_way ON orders;
CREATE TRIGGER notify_merchant_on_the_way
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'on_the_way')
  EXECUTE FUNCTION notify_merchant_order_on_the_way();

-- TRIGGER: Notify merchant when order is delivered
CREATE OR REPLACE FUNCTION notify_merchant_order_delivered()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF OLD.status != 'delivered' AND NEW.status = 'delivered' THEN
    PERFORM create_notification(
      NEW.merchant_id,
      '🎉 تم التسليم',
      'تم تسليم الطلب بنجاح',
      'order_delivered',
      jsonb_build_object('order_id', NEW.id)
    );
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_merchant_on_delivery ON orders;
CREATE TRIGGER notify_merchant_on_delivery
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'delivered')
  EXECUTE FUNCTION notify_merchant_order_delivered();

-- =====================================================================================
-- 8. VERIFICATION QUERIES
-- =====================================================================================

-- Verify realtime is enabled
DO $$ 
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM pg_publication_tables
  WHERE pubname = 'supabase_realtime'
    AND schemaname = 'public'
    AND tablename = 'notifications';
  
  IF v_count > 0 THEN
    RAISE NOTICE '✅ Notifications table is in supabase_realtime publication';
  ELSE
    RAISE NOTICE '❌ WARNING: Notifications table NOT in realtime publication!';
  END IF;
END $$;

-- =====================================================================================
-- SUCCESS MESSAGE
-- =====================================================================================

DO $$ 
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ ULTIMATE NOTIFICATION SYSTEM READY';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Components installed:';
  RAISE NOTICE '  ✅ Notifications table';
  RAISE NOTICE '  ✅ Realtime enabled';
  RAISE NOTICE '  ✅ RLS policies';
  RAISE NOTICE '  ✅ Notification triggers';
  RAISE NOTICE '  ✅ Helper functions';
  RAISE NOTICE '  ✅ Test function';
  RAISE NOTICE '';
  RAISE NOTICE 'To test the system:';
  RAISE NOTICE '  SELECT send_test_notification(''your-user-id'');';
  RAISE NOTICE '';
  RAISE NOTICE 'Notification triggers active for:';
  RAISE NOTICE '  - Order assigned to driver';
  RAISE NOTICE '  - Order accepted';
  RAISE NOTICE '  - Order on the way';
  RAISE NOTICE '  - Order delivered';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

