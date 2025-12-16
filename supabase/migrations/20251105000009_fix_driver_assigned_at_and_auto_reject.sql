-- =====================================================================================
-- FIX: Ensure driver_assigned_at is set and improve auto-reject detection
-- =====================================================================================
-- This fixes orders that have drivers but no driver_assigned_at timestamp
-- and improves the auto-reject function to handle edge cases
-- =====================================================================================

-- Step 1: Fix existing orders that have drivers but no driver_assigned_at
-- Use created_at as fallback if driver_assigned_at is missing
-- But only if the order was created more than 30 seconds ago (otherwise use NOW())
DO $$
DECLARE
  v_fixed_count INTEGER;
BEGIN
  -- Fix orders: if created > 30 seconds ago, use created_at, otherwise use NOW()
  UPDATE orders
  SET driver_assigned_at = CASE
    WHEN created_at < (NOW() - INTERVAL '30 seconds') THEN created_at
    ELSE NOW()
  END
  WHERE status = 'pending'
    AND driver_id IS NOT NULL
    AND driver_assigned_at IS NULL;
  
  GET DIAGNOSTICS v_fixed_count = ROW_COUNT;
  RAISE NOTICE 'Fixed % orders by setting driver_assigned_at', v_fixed_count;
END $$;

-- Step 2: Ensure the trigger sets driver_assigned_at when driver is assigned
CREATE OR REPLACE FUNCTION track_driver_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- When a driver is assigned to a pending order, set timestamp
  IF NEW.status = 'pending' 
     AND NEW.driver_id IS NOT NULL 
     AND (OLD.driver_id IS NULL OR OLD.driver_id IS DISTINCT FROM NEW.driver_id) THEN
    -- Set driver_assigned_at if it's not already set
    IF NEW.driver_assigned_at IS NULL THEN
      NEW.driver_assigned_at = NOW();
      RAISE NOTICE 'Set driver_assigned_at to NOW() for order %', NEW.id;
    END IF;
  END IF;
  
  -- When driver is removed from pending order, clear timestamp
  IF NEW.status = 'pending' 
     AND NEW.driver_id IS NULL 
     AND OLD.driver_id IS NOT NULL THEN
    NEW.driver_assigned_at = NULL;
    RAISE NOTICE 'Cleared driver_assigned_at for order %', NEW.id;
  END IF;
  
  -- When status changes from pending to accepted/rejected, clear timestamp
  IF NEW.status != 'pending' AND OLD.status = 'pending' THEN
    NEW.driver_assigned_at = NULL;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Recreate the trigger
DROP TRIGGER IF EXISTS track_driver_assignment_trigger ON orders;
CREATE TRIGGER track_driver_assignment_trigger
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION track_driver_assignment();

-- Step 3: Also set driver_assigned_at on INSERT if driver is assigned immediately
CREATE OR REPLACE FUNCTION track_driver_assignment_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- When a new order is created with a driver already assigned
  IF NEW.status = 'pending' 
     AND NEW.driver_id IS NOT NULL 
     AND NEW.driver_assigned_at IS NULL THEN
    NEW.driver_assigned_at = NOW();
    RAISE NOTICE 'Set driver_assigned_at to NOW() for new order %', NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for INSERT
DROP TRIGGER IF EXISTS track_driver_assignment_on_insert_trigger ON orders;
CREATE TRIGGER track_driver_assignment_on_insert_trigger
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION track_driver_assignment_on_insert();

-- Step 4: Improve auto_reject_expired_orders to also handle orders without driver_assigned_at
-- but with driver_id set for a long time (fallback detection)
-- 
-- This function handles driver rotation and offline marking:
-- 1. Marks timed-out drivers as offline (is_online = false)
-- 2. Adds driver to order_rejected_drivers (prevents reassignment to same driver)
-- 3. Removes driver from order
-- 4. Calls auto_assign_order() which will find next available driver
--    (find_next_available_driver excludes drivers in order_rejected_drivers)
-- 5. Process repeats until driver accepts or no drivers available
CREATE OR REPLACE FUNCTION auto_reject_expired_orders()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_order RECORD;
  v_processed INTEGER := 0;
  v_reassignment_success BOOLEAN;
BEGIN
  -- Loop through all expired orders
  -- Case 1: Orders with driver_assigned_at that's expired
  FOR expired_order IN
    SELECT 
      id, 
      driver_id, 
      driver_assigned_at, 
      created_at,
      CASE 
        WHEN driver_assigned_at IS NOT NULL 
        THEN EXTRACT(EPOCH FROM (NOW() - driver_assigned_at))::INTEGER
        WHEN created_at < (NOW() - INTERVAL '30 seconds')
        THEN EXTRACT(EPOCH FROM (NOW() - created_at))::INTEGER
        ELSE NULL
      END as elapsed_seconds
    FROM orders
    WHERE status = 'pending'
      AND driver_id IS NOT NULL
      AND (
        -- Standard case: driver_assigned_at exists and is expired (30+ seconds)
        (driver_assigned_at IS NOT NULL AND driver_assigned_at < (NOW() - INTERVAL '30 seconds'))
        OR
        -- Fallback case: driver_assigned_at is NULL but order was created > 30 seconds ago
        -- This handles orders where the trigger didn't set driver_assigned_at
        (driver_assigned_at IS NULL AND created_at < (NOW() - INTERVAL '30 seconds'))
      )
    FOR UPDATE SKIP LOCKED
  LOOP
    BEGIN
      RAISE NOTICE 'Processing expired order %: driver=%, elapsed=% seconds', 
        expired_order.id, expired_order.driver_id, expired_order.elapsed_seconds;
      
      -- Step 1: Add driver to rejected list for this order (using DELETE+INSERT instead of ON CONFLICT)
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_rejected_drivers') THEN
        DELETE FROM order_rejected_drivers WHERE order_id = expired_order.id AND driver_id = expired_order.driver_id;
        INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
        VALUES (expired_order.id, expired_order.driver_id, 'timeout');
      END IF;
      
      -- Step 2: Update order_assignments table status (if table exists)
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_assignments') THEN
        UPDATE order_assignments
        SET status = 'timeout', responded_at = NOW()
        WHERE order_id = expired_order.id 
          AND driver_id = expired_order.driver_id 
          AND status = 'pending';
      END IF;
      
      -- Step 3: Mark driver as OFFLINE (they're not responding)
      UPDATE users
      SET 
        is_online = FALSE,
        updated_at = NOW()
      WHERE id = expired_order.driver_id
        AND role = 'driver'; -- Safety check to only update drivers
      
      -- Step 4: Send notification to driver about being marked offline
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
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
      END IF;
      
      -- Step 5: Remove driver from order FIRST
      -- This must happen before calling auto_assign_order
      UPDATE orders
      SET 
        driver_id = NULL,
        driver_assigned_at = NULL,
        updated_at = NOW()
      WHERE id = expired_order.id;
      
      -- Verify the driver was removed
      IF NOT FOUND THEN
        RAISE WARNING 'Failed to remove driver from order %', expired_order.id;
        CONTINUE; -- Skip to next order
      END IF;
      
      -- Step 6: Try to assign to next available driver (ROTATION)
      -- This ensures orders rotate between drivers until someone accepts
      -- The find_next_available_driver() function automatically excludes:
      --   - Drivers already in order_rejected_drivers for this order
      --   - Drivers who are offline (is_online = false)
      --   - Drivers with active orders
      v_reassignment_success := auto_assign_order(expired_order.id);
      
      IF v_reassignment_success THEN
        RAISE NOTICE '✅ Driver % timed out on order %. Marked OFFLINE and reassigned to next driver.', 
          expired_order.driver_id, expired_order.id;
      ELSE
        -- Check if order was marked as rejected (no drivers available)
        DECLARE
          v_order_status TEXT;
        BEGIN
          SELECT status INTO v_order_status
          FROM orders
          WHERE id = expired_order.id;
          
          IF v_order_status = 'rejected' THEN
            RAISE NOTICE '✅ Driver % timed out on order %. Marked OFFLINE. Order marked as rejected (no more drivers available).', 
              expired_order.driver_id, expired_order.id;
          ELSE
            RAISE NOTICE '⚠️ Driver % timed out on order %. Marked OFFLINE but failed to reassign (order status: %).', 
              expired_order.driver_id, expired_order.id, v_order_status;
          END IF;
        END;
      END IF;
      
      v_processed := v_processed + 1;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING '❌ Error processing expired order %: %', expired_order.id, SQLERRM;
        -- Continue with next order
    END;
  END LOOP;
  
  RETURN v_processed;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in auto_reject_expired_orders: %', SQLERRM;
    RETURN 0;
END;
$$;

-- Step 5: Update verification query to match new logic
DO $$
DECLARE
  v_fixed_count INTEGER;
  v_expired_count INTEGER;
BEGIN
  -- Count orders we just fixed
  SELECT COUNT(*) INTO v_fixed_count
  FROM orders
  WHERE status = 'pending'
    AND driver_id IS NOT NULL
    AND driver_assigned_at IS NOT NULL
    AND driver_assigned_at = created_at; -- Orders we just updated
    
  -- Count expired orders (with new logic)
  SELECT COUNT(*) INTO v_expired_count
  FROM orders
  WHERE status = 'pending'
    AND driver_id IS NOT NULL
    AND (
      (driver_assigned_at IS NOT NULL AND driver_assigned_at < (NOW() - INTERVAL '30 seconds'))
      OR
      (driver_assigned_at IS NULL AND created_at < (NOW() - INTERVAL '30 seconds'))
    );
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIX APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Fixed % orders (set driver_assigned_at)', v_fixed_count;
  RAISE NOTICE 'Found % expired orders that should be processed', v_expired_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Triggers created:';
  RAISE NOTICE '  - track_driver_assignment_trigger (on UPDATE)';
  RAISE NOTICE '  - track_driver_assignment_on_insert_trigger (on INSERT)';
  RAISE NOTICE '';
  RAISE NOTICE 'Auto-reject function now handles:';
  RAISE NOTICE '  - Orders with expired driver_assigned_at';
  RAISE NOTICE '  - Orders with driver_id but no driver_assigned_at (fallback)';
  RAISE NOTICE '';
  RAISE NOTICE 'Driver rotation and offline marking:';
  RAISE NOTICE '  ✅ Timed-out drivers are marked as offline (is_online = false)';
  RAISE NOTICE '  ✅ Timed-out drivers are added to order_rejected_drivers';
  RAISE NOTICE '  ✅ Orders are automatically reassigned to next available driver';
  RAISE NOTICE '  ✅ Rotation continues until driver accepts or no drivers available';
  RAISE NOTICE '';
  IF v_expired_count > 0 THEN
    RAISE NOTICE 'Run this to process expired orders:';
    RAISE NOTICE '  SELECT auto_reject_expired_orders();';
  END IF;
  RAISE NOTICE '========================================';
END $$;

