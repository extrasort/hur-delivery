-- =====================================================================================
-- UNIVERSAL NOTIFICATION MESSAGES
-- =====================================================================================
-- Updates notification triggers to use more concise, universal messages
-- without specific names, addresses, or coordinates
-- =====================================================================================

-- =====================================================================================
-- 1. UPDATE: Notify driver when order is assigned (universal)
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_driver_order_assigned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only notify when driver_id changes from NULL to a value
  IF OLD.driver_id IS NULL AND NEW.driver_id IS NOT NULL THEN
    -- Insert universal notification for driver
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
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

-- =====================================================================================
-- 2. UPDATE: Notify merchant when driver accepts order (universal)
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_merchant_order_accepted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_name TEXT;
BEGIN
  -- Only notify when status changes TO 'accepted'
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    -- Get driver name for data field only
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    
    -- Insert universal notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.merchant_id,
      '✅ تم قبول الطلب',
      'السائق قبل الطلب وهو في طريقه للاستلام',
      'order_accepted',
      jsonb_build_object(
        'order_id', NEW.id,
        'driver_id', NEW.driver_id,
        'driver_name', v_driver_name,
        'customer_name', NEW.customer_name
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- =====================================================================================
-- 3. UPDATE: Notify merchant when driver rejects order (universal)
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
    -- Insert universal notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      v_merchant_id,
      '⚠️ تم رفض الطلب',
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

-- =====================================================================================
-- 4. UPDATE: Notify merchant when order is on the way (universal)
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_merchant_order_on_the_way()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_name TEXT;
BEGIN
  -- Only notify when status changes TO 'on_the_way'
  IF OLD.status != 'on_the_way' AND NEW.status = 'on_the_way' THEN
    -- Get driver name for data field only
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    
    -- Insert universal notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.merchant_id,
      '🚗 السائق في الطريق',
      'السائق في طريقه للتوصيل',
      'order_status_update',
      jsonb_build_object(
        'order_id', NEW.id,
        'status', 'on_the_way',
        'driver_name', v_driver_name,
        'customer_name', NEW.customer_name
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- =====================================================================================
-- 5. UPDATE: Notify merchant when order is delivered (universal)
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_merchant_order_delivered()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_name TEXT;
BEGIN
  -- Only notify when status changes TO 'delivered'
  IF OLD.status != 'delivered' AND NEW.status = 'delivered' THEN
    -- Get driver name for data field only
    SELECT name INTO v_driver_name FROM users WHERE id = NEW.driver_id;
    
    -- Insert universal notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.merchant_id,
      '🎉 تم التسليم',
      'تم تسليم الطلب بنجاح',
      'order_delivered',
      jsonb_build_object(
        'order_id', NEW.id,
        'driver_name', v_driver_name,
        'customer_name', NEW.customer_name,
        'delivery_fee', NEW.delivery_fee,
        'total_amount', NEW.total_amount
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- =====================================================================================
-- 6. UPDATE: Notify merchant when all drivers reject (universal)
-- =====================================================================================

CREATE OR REPLACE FUNCTION notify_merchant_all_rejected()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only notify when status changes TO 'rejected'
  IF OLD.status != 'rejected' AND NEW.status = 'rejected' THEN
    -- Insert universal notification for merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      NEW.merchant_id,
      '❌ لم يتم العثور على سائق',
      'يمكنك إعادة نشر الطلب بزيادة الأجرة (+500 د.ع)',
      'order_cancelled',
      jsonb_build_object(
        'order_id', NEW.id,
        'customer_name', NEW.customer_name,
        'repost_available', true,
        'fee_increase', 500
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- =====================================================================================
-- 7. UPDATE: Timeout offline notification (universal)
-- =====================================================================================

-- Update the timeout notification in the auto_reject function
CREATE OR REPLACE FUNCTION auto_reject_expired_orders()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_order RECORD;
  v_count INTEGER := 0;
BEGIN
  FOR expired_order IN
    SELECT id, driver_id, driver_assigned_at
    FROM orders
    WHERE status = 'pending'
      AND driver_id IS NOT NULL
      AND driver_assigned_at IS NOT NULL
      AND driver_assigned_at < (NOW() - INTERVAL '30 seconds')
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Add driver to rejected list for timeout
    INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
    VALUES (expired_order.id, expired_order.driver_id, 'timeout')
    ON CONFLICT (order_id, driver_id) DO NOTHING;
    
    -- Update assignment record
    UPDATE order_assignments
    SET status = 'timeout', responded_at = NOW()
    WHERE order_id = expired_order.id 
      AND driver_id = expired_order.driver_id 
      AND status = 'pending';
    
    -- Mark driver as OFFLINE (they're not responding)
    UPDATE users
    SET 
      is_online = FALSE,
      updated_at = NOW()
    WHERE id = expired_order.driver_id;
    
    -- Remove driver from order
    UPDATE orders
    SET 
      driver_id = NULL,
      driver_assigned_at = NULL,
      updated_at = NOW()
    WHERE id = expired_order.id;
    
    -- Try to assign to next available driver
    PERFORM auto_assign_order(expired_order.id);
    
    -- Send universal notification to timed-out driver
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      expired_order.driver_id,
      '⚠️ تم وضعك في وضع غير متصل',
      'لم تقم بالرد على الطلب خلال الوقت المحدد',
      'system',
      jsonb_build_object(
        'order_id', expired_order.id,
        'reason', 'timeout',
        'action', 'marked_offline'
      )
    );
    
    v_count := v_count + 1;
    
    RAISE NOTICE 'Driver % timed out on order % and marked OFFLINE. Reassigning...', 
      expired_order.driver_id, expired_order.id;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- =====================================================================================
-- COMMENTS
-- =====================================================================================

COMMENT ON FUNCTION notify_driver_order_assigned IS 
  'Creates universal notification when order is assigned to driver';

COMMENT ON FUNCTION notify_merchant_order_accepted IS 
  'Creates universal notification when driver accepts order';

COMMENT ON FUNCTION notify_merchant_order_reassigned IS 
  'Creates universal notification when driver rejects order';

COMMENT ON FUNCTION notify_merchant_order_on_the_way IS 
  'Creates universal notification when driver starts delivery';

COMMENT ON FUNCTION notify_merchant_order_delivered IS 
  'Creates universal notification when order is delivered';

COMMENT ON FUNCTION notify_merchant_all_rejected IS 
  'Creates universal notification when all drivers reject order';

COMMENT ON FUNCTION auto_reject_expired_orders IS 
  'Auto-rejects expired orders with universal timeout notification';

-- =====================================================================================
-- SUCCESS MESSAGE
-- =====================================================================================

DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'UNIVERSAL NOTIFICATIONS APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'All notifications now use concise,';
  RAISE NOTICE 'universal messages without specific';
  RAISE NOTICE 'names, addresses, or coordinates.';
  RAISE NOTICE '';
  RAISE NOTICE 'Detailed data is still stored in';
  RAISE NOTICE 'the notification data field for';
  RAISE NOTICE 'internal use.';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

