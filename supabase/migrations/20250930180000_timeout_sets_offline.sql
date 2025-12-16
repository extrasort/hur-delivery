-- =====================================================================================
-- AUTO-REJECT TIMEOUT - MARK DRIVER OFFLINE
-- =====================================================================================
-- When a driver times out on an order, they get marked as offline
-- This ensures only responsive drivers receive orders
-- =====================================================================================

-- Update the auto-reject function to also mark driver as offline
CREATE OR REPLACE FUNCTION auto_reject_expired_orders()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_order RECORD;
  v_count INTEGER := 0;
BEGIN
  -- Loop through all expired orders (assigned more than 30 seconds ago)
  FOR expired_order IN
    SELECT id, driver_id, driver_assigned_at
    FROM orders
    WHERE status = 'pending'
      AND driver_id IS NOT NULL
      AND driver_assigned_at IS NOT NULL
      AND driver_assigned_at < (NOW() - INTERVAL '30 seconds')
    FOR UPDATE SKIP LOCKED  -- Prevent race conditions
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
    
    -- Send notification to timed-out driver
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      expired_order.driver_id,
      '⚠️ تم وضعك في وضع غير متصل',
      'لم تقم بالرد على الطلب خلال 30 ثانية. تم تحويلك إلى وضع غير متصل تلقائياً.',
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

COMMENT ON FUNCTION auto_reject_expired_orders IS 
  'Auto-rejects expired orders, marks driver as OFFLINE, and reassigns to next driver';

-- =====================================================================================
-- SUCCESS MESSAGE
-- =====================================================================================

DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TIMEOUT OFFLINE FEATURE INSTALLED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'When driver times out (30 seconds):';
  RAISE NOTICE '  1. ✅ Driver added to rejection list';
  RAISE NOTICE '  2. ✅ Driver marked as OFFLINE';
  RAISE NOTICE '  3. ✅ Driver receives notification';
  RAISE NOTICE '  4. ✅ Order reassigned to next driver';
  RAISE NOTICE '';
  RAISE NOTICE 'Driver must manually go back ONLINE';
  RAISE NOTICE 'to receive new orders.';
  RAISE NOTICE '';
  RAISE NOTICE 'This ensures only responsive drivers';
  RAISE NOTICE 'are actively receiving orders.';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

