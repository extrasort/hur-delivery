-- =====================================================================================
-- AUTOMATIC NOTIFICATION TRIGGERS
-- =====================================================================================
-- Creates database triggers that automatically insert notification records
-- when key events happen (order assigned, accepted, rejected, etc.)
-- =====================================================================================

-- =====================================================================================
-- 1. TRIGGER: Notify driver when order is assigned
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_driver_order_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_customer_name TEXT;
  v_pickup_address TEXT;
BEGIN
  -- Only notify when driver_id changes from NULL to a value
  IF OLD.driver_id IS NULL AND NEW.driver_id IS NOT NULL THEN
    -- Get order details
    v_customer_name := NEW.customer_name;
    v_pickup_address := NEW.pickup_address;
    
    -- Insert notification for driver
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.driver_id,
      '📦 طلب توصيل جديد',
      'لديك طلب من ' || v_customer_name || E'\n' || 
      'الاستلام: ' || v_pickup_address || E'\n' ||
      '⏱️ اضغط قبول خلال 30 ثانية',
      'order_assigned',
      jsonb_build_object(
        'order_id', NEW.id,
        'customer_name', v_customer_name,
        'pickup_address', v_pickup_address
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

-- =====================================================================================
-- 2. TRIGGER: Notify merchant when driver accepts order
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_merchant_order_accepted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_name TEXT;
  v_customer_name TEXT;
BEGIN
  -- Only notify when status changes TO 'accepted'
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    -- Get driver name
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    v_customer_name := NEW.customer_name;
    
    -- Insert notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.merchant_id,
      '✅ تم قبول الطلب',
      'قبل السائق ' || COALESCE(v_driver_name, 'السائق') || ' طلب ' || v_customer_name || E'\n' ||
      'وهو في طريقه للاستلام',
      'order_accepted',
      jsonb_build_object(
        'order_id', NEW.id,
        'driver_id', NEW.driver_id,
        'driver_name', v_driver_name,
        'customer_name', v_customer_name
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

-- =====================================================================================
-- 3. TRIGGER: Notify merchant when driver rejects order
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_merchant_order_reassigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_merchant_id UUID;
  v_customer_name TEXT;
  v_rejection_count INTEGER;
BEGIN
  -- Get order details
  SELECT merchant_id, customer_name INTO v_merchant_id, v_customer_name
  FROM orders
  WHERE id = NEW.order_id;
  
  -- Count rejections for this order
  SELECT COUNT(*) INTO v_rejection_count
  FROM order_rejected_drivers
  WHERE order_id = NEW.order_id;
  
  -- Only notify if it's a manual reject (not timeout)
  IF NEW.reason = 'manual_reject' THEN
    -- Insert notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      v_merchant_id,
      '⚠️ تم رفض الطلب',
      'رفض السائق طلب ' || v_customer_name || E'\n' ||
      'جاري البحث عن سائق آخر...',
      'order_rejected',
      jsonb_build_object(
        'order_id', NEW.order_id,
        'customer_name', v_customer_name,
        'rejection_count', v_rejection_count
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_merchant_on_rejection ON order_rejected_drivers;
CREATE TRIGGER notify_merchant_on_rejection
  AFTER INSERT ON order_rejected_drivers
  FOR EACH ROW
  EXECUTE FUNCTION notify_merchant_order_reassigned();

-- =====================================================================================
-- 4. TRIGGER: Notify merchant when order is on the way
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_merchant_order_on_the_way()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_name TEXT;
  v_customer_name TEXT;
BEGIN
  -- Only notify when status changes TO 'on_the_way'
  IF OLD.status != 'on_the_way' AND NEW.status = 'on_the_way' THEN
    -- Get driver name
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    v_customer_name := NEW.customer_name;
    
    -- Insert notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.merchant_id,
      '🚗 السائق في الطريق',
      'السائق ' || COALESCE(v_driver_name, 'السائق') || ' في طريقه لتوصيل طلب ' || v_customer_name,
      'order_status_update',
      jsonb_build_object(
        'order_id', NEW.id,
        'status', 'on_the_way',
        'driver_name', v_driver_name,
        'customer_name', v_customer_name
      )
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

-- =====================================================================================
-- 5. TRIGGER: Notify merchant when order is delivered
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_merchant_order_delivered()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_name TEXT;
  v_customer_name TEXT;
BEGIN
  -- Only notify when status changes TO 'delivered'
  IF OLD.status != 'delivered' AND NEW.status = 'delivered' THEN
    -- Get driver name
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    v_customer_name := NEW.customer_name;
    
    -- Insert notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.merchant_id,
      '🎉 تم التسليم',
      'تم تسليم طلب ' || v_customer_name || ' بنجاح' || E'\n' ||
      'السائق: ' || COALESCE(v_driver_name, 'غير معروف'),
      'order_delivered',
      jsonb_build_object(
        'order_id', NEW.id,
        'driver_name', v_driver_name,
        'customer_name', v_customer_name,
        'delivery_fee', NEW.delivery_fee,
        'total_amount', NEW.total_amount
      )
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
-- 6. TRIGGER: Notify merchant when all drivers reject
-- =====================================================================================

-- This is already handled in the auto_assign_order function
-- when it sets status to 'rejected', but we'll add a trigger too

CREATE OR REPLACE FUNCTION notify_merchant_all_rejected()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_customer_name TEXT;
BEGIN
  -- Only notify when status changes TO 'rejected'
  IF OLD.status != 'rejected' AND NEW.status = 'rejected' THEN
    v_customer_name := NEW.customer_name;
    
    -- Insert notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.merchant_id,
      '❌ لم يتم العثور على سائق',
      'رفض جميع السائقين طلب ' || v_customer_name || E'\n' ||
      'يمكنك إعادة نشره بزيادة الأجرة (+500 د.ع)',
      'order_cancelled',
      jsonb_build_object(
        'order_id', NEW.id,
        'customer_name', v_customer_name,
        'repost_available', true,
        'fee_increase', 500
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_merchant_all_rejected ON orders;
CREATE TRIGGER notify_merchant_all_rejected
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'rejected')
  EXECUTE FUNCTION notify_merchant_all_rejected();

-- =====================================================================================
-- 7. INDEX: Speed up notification queries
-- =====================================================================================

-- Already created in main migration, but ensure it exists
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
  ON notifications(user_id, created_at DESC) 
  WHERE is_read = FALSE;

-- =====================================================================================
-- COMMENTS
-- =====================================================================================

COMMENT ON FUNCTION notify_driver_order_assigned IS 
  'Automatically creates notification when order is assigned to driver';

COMMENT ON FUNCTION notify_merchant_order_accepted IS 
  'Automatically creates notification when driver accepts order';

COMMENT ON FUNCTION notify_merchant_order_reassigned IS 
  'Automatically creates notification when driver rejects order';

COMMENT ON FUNCTION notify_merchant_order_on_the_way IS 
  'Automatically creates notification when driver starts delivery';

COMMENT ON FUNCTION notify_merchant_order_delivered IS 
  'Automatically creates notification when order is delivered';

COMMENT ON FUNCTION notify_merchant_all_rejected IS 
  'Automatically creates notification when all drivers reject order';

-- =====================================================================================
-- SUCCESS MESSAGE
-- =====================================================================================

DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'NOTIFICATION TRIGGERS INSTALLED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Automatic notifications will be created for:';
  RAISE NOTICE '  ✅ Driver: When order is assigned';
  RAISE NOTICE '  ✅ Merchant: When driver accepts order';
  RAISE NOTICE '  ✅ Merchant: When driver rejects order';
  RAISE NOTICE '  ✅ Merchant: When order is on the way';
  RAISE NOTICE '  ✅ Merchant: When order is delivered';
  RAISE NOTICE '  ✅ Merchant: When all drivers reject';
  RAISE NOTICE '';
  RAISE NOTICE 'The Flutter app will poll notifications table';
  RAISE NOTICE 'and display them as local notifications.';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

