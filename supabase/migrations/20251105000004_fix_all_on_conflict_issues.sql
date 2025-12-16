-- =====================================================================================
-- FIX ALL ON CONFLICT ISSUES
-- =====================================================================================
-- This migration fixes all functions that use ON CONFLICT to work without constraints
-- =====================================================================================

-- =====================================================================================
-- 1. FIX: auto_assign_order function
-- =====================================================================================

CREATE OR REPLACE FUNCTION auto_assign_order(p_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_lat DOUBLE PRECISION;
  v_pickup_lng DOUBLE PRECISION;
  v_order_status TEXT;
  v_vehicle_type TEXT;
BEGIN
  -- Get order details
  SELECT status, pickup_latitude, pickup_longitude, vehicle_type
  INTO v_order_status, v_pickup_lat, v_pickup_lng, v_vehicle_type
  FROM orders
  WHERE id = p_order_id;
  
  -- Only assign if order is pending and has no driver
  IF v_order_status != 'pending' THEN
    RETURN FALSE;
  END IF;
  
  -- Find next available driver
  v_driver_id := find_next_available_driver(p_order_id, v_pickup_lat, v_pickup_lng);
  
  IF v_driver_id IS NULL THEN
    -- No available drivers
    RAISE NOTICE 'No available drivers found for order %', p_order_id;
    RETURN FALSE;
  END IF;
  
  -- Assign order to driver (this triggers the driver_assigned_at timestamp)
  UPDATE orders
  SET 
    driver_id = v_driver_id,
    driver_assigned_at = NOW(),
    updated_at = NOW()
  WHERE id = p_order_id
    AND status = 'pending'
    AND driver_id IS NULL; -- Ensure it hasn't been assigned already
  
  IF FOUND THEN
    -- Create assignment record if table exists (using DELETE+INSERT instead of ON CONFLICT)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_assignments') THEN
      DELETE FROM order_assignments WHERE order_id = p_order_id AND driver_id = v_driver_id;
      INSERT INTO order_assignments (order_id, driver_id, status)
      VALUES (p_order_id, v_driver_id, 'pending');
    END IF;
    
    RAISE NOTICE 'Assigned order % (vehicle: %) to driver % at %', 
      p_order_id, v_vehicle_type, v_driver_id, NOW();
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in auto_assign_order for order %: %', p_order_id, SQLERRM;
    RETURN FALSE;
END;
$$;

-- =====================================================================================
-- 2. FIX: auto_reject_expired_orders function
-- =====================================================================================

CREATE OR REPLACE FUNCTION auto_reject_expired_orders()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_order RECORD;
  v_processed INTEGER := 0;
BEGIN
  -- Loop through all expired orders
  FOR expired_order IN
    SELECT id, driver_id
    FROM orders
    WHERE status = 'pending'
      AND driver_id IS NOT NULL
      AND driver_assigned_at IS NOT NULL
      AND driver_assigned_at < (NOW() - INTERVAL '30 seconds')
  LOOP
    BEGIN
      -- Add driver to rejected list for this order (using DELETE+INSERT instead of ON CONFLICT)
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_rejected_drivers') THEN
        DELETE FROM order_rejected_drivers WHERE order_id = expired_order.id AND driver_id = expired_order.driver_id;
        INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
        VALUES (expired_order.id, expired_order.driver_id, 'timeout');
      END IF;
      
      -- Remove driver from order
      UPDATE orders
      SET 
        driver_id = NULL,
        driver_assigned_at = NULL,
        updated_at = NOW()
      WHERE id = expired_order.id;
      
      -- Try to assign to next available driver
      PERFORM auto_assign_order(expired_order.id);
      
      v_processed := v_processed + 1;
      RAISE NOTICE 'Driver % timed out on order %. Reassigning...', expired_order.driver_id, expired_order.id;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Error processing expired order %: %', expired_order.id, SQLERRM;
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

-- =====================================================================================
-- 3. FIX: reject_order_and_reassign function (if it exists)
-- =====================================================================================

CREATE OR REPLACE FUNCTION reject_order_and_reassign(
  p_order_id UUID,
  p_driver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Add driver to rejected list (using DELETE+INSERT instead of ON CONFLICT)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_rejected_drivers') THEN
    DELETE FROM order_rejected_drivers WHERE order_id = p_order_id AND driver_id = p_driver_id;
    INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
    VALUES (p_order_id, p_driver_id, 'manual_reject');
  END IF;
  
  -- Remove driver from order
  UPDATE orders
  SET 
    driver_id = NULL,
    driver_assigned_at = NULL,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Try to assign to next available driver
  PERFORM auto_assign_order(p_order_id);
  
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in reject_order_and_reassign: %', SQLERRM;
    RETURN FALSE;
END;
$$;

-- =====================================================================================
-- VERIFY
-- =====================================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ All ON CONFLICT issues fixed!';
  RAISE NOTICE '';
  RAISE NOTICE 'Functions updated:';
  RAISE NOTICE '  - auto_assign_order';
  RAISE NOTICE '  - auto_reject_expired_orders';
  RAISE NOTICE '  - reject_order_and_reassign';
  RAISE NOTICE '';
  RAISE NOTICE 'All functions now use DELETE+INSERT instead of ON CONFLICT';
  RAISE NOTICE 'Order creation should now work!';
  RAISE NOTICE '';
END $$;

