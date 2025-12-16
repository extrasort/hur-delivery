-- =====================================================================================
-- ENSURE AUTO_ASSIGN_ORDER SETS driver_assigned_at
-- =====================================================================================
-- This migration ensures that auto_assign_order always sets driver_assigned_at
-- when assigning a driver to an order
-- =====================================================================================

-- Update auto_assign_order to ensure driver_assigned_at is always set
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
  v_current_driver UUID;
  v_vehicle_type TEXT;
  v_rejection_count INTEGER;
BEGIN
  -- Get order details including vehicle type
  SELECT status, pickup_latitude, pickup_longitude, vehicle_type, driver_id
  INTO v_order_status, v_pickup_lat, v_pickup_lng, v_vehicle_type, v_current_driver
  FROM orders
  WHERE id = p_order_id;
  
  -- Only assign if order is pending
  IF v_order_status != 'pending' THEN
    RAISE NOTICE 'Order % is not pending (status: %)', p_order_id, v_order_status;
    RETURN FALSE;
  END IF;
  
  -- Check if order already has a driver assigned
  IF v_current_driver IS NOT NULL THEN
    RAISE NOTICE 'Order % already has driver %', p_order_id, v_current_driver;
    RETURN FALSE;
  END IF;
  
  -- Count how many drivers have rejected this order
  SELECT COUNT(*) INTO v_rejection_count
  FROM order_rejected_drivers
  WHERE order_id = p_order_id;
  
  -- Find next available driver with compatible vehicle type
  -- Check if find_next_available_driver accepts vehicle_type parameter
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'find_next_available_driver'
    AND pg_get_function_arguments(p.oid) LIKE '%vehicle_type%'
  ) THEN
    -- Function accepts vehicle_type parameter
    v_driver_id := find_next_available_driver(p_order_id, v_pickup_lat, v_pickup_lng, v_vehicle_type);
  ELSE
    -- Function doesn't accept vehicle_type parameter
    v_driver_id := find_next_available_driver(p_order_id, v_pickup_lat, v_pickup_lng);
  END IF;
  
  IF v_driver_id IS NULL THEN
    -- No available drivers - mark order as rejected
    RAISE NOTICE 'No available drivers for order % (vehicle type: %). Total rejections: %', 
      p_order_id, v_vehicle_type, v_rejection_count;
    
    UPDATE orders
    SET 
      status = 'rejected',
      rejected_at = NOW(),
      rejection_reason = CASE 
        WHEN v_vehicle_type IS NOT NULL THEN 
          'No available drivers with ' || v_vehicle_type
        ELSE 
          'No available drivers'
      END,
      updated_at = NOW()
    WHERE id = p_order_id;
    
    -- Notify merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    SELECT 
      merchant_id,
      'تم رفض الطلب',
      'لم يتم العثور على سائق متاح. يمكنك إعادة نشر الطلب بزيادة أجرة التوصيل.',
      'order_cancelled',
      jsonb_build_object('order_id', p_order_id, 'repost_available', true)
    FROM orders
    WHERE id = p_order_id;
    
    RETURN FALSE;
  END IF;
  
  -- Assign order to driver and SET driver_assigned_at timestamp
  UPDATE orders
  SET 
    driver_id = v_driver_id,
    driver_assigned_at = NOW(),  -- CRITICAL: Always set this timestamp
    updated_at = NOW()
  WHERE id = p_order_id
    AND status = 'pending'
    AND driver_id IS NULL; -- Ensure it hasn't been assigned already
  
  IF FOUND THEN
    -- Create assignment record if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_assignments') THEN
      INSERT INTO order_assignments (order_id, driver_id, status)
      VALUES (p_order_id, v_driver_id, 'pending')
      ON CONFLICT (order_id, driver_id) DO UPDATE
      SET status = 'pending', created_at = NOW();
    END IF;
    
    RAISE NOTICE 'Assigned order % (vehicle: %) to driver % at %', 
      p_order_id, v_vehicle_type, v_driver_id, NOW();
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$;

COMMENT ON FUNCTION auto_assign_order(UUID) IS 
  'Automatically assigns an order to the next available driver with compatible vehicle type. 
   Always sets driver_assigned_at timestamp when assigning. Marks order as rejected if no compatible drivers are found.';

-- =====================================================================================
-- CREATE DATABASE FUNCTION TO BE CALLED BY EDGE FUNCTION
-- =====================================================================================

-- Create a function that the edge function can call to check and process pending orders
CREATE OR REPLACE FUNCTION check_and_assign_pending_orders()
RETURNS TABLE (
  order_id UUID,
  action_taken TEXT,
  driver_id UUID,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_driver_id UUID;
  v_assigned BOOLEAN;
BEGIN
  -- Process orders that need assignment or reassignment
  FOR v_order IN
    SELECT 
      o.id,
      o.created_at,
      o.driver_id,
      o.driver_assigned_at,
      o.pickup_latitude,
      o.pickup_longitude,
      o.vehicle_type
    FROM orders o
    WHERE o.status = 'pending'
      AND (
        -- Case 1: Orders created >= 30 seconds ago with no driver
        (o.driver_id IS NULL AND o.created_at < (NOW() - INTERVAL '30 seconds'))
        OR
        -- Case 2: Orders with driver_assigned_at >= 30 seconds ago (driver hasn't accepted)
        (o.driver_assigned_at IS NOT NULL AND o.driver_assigned_at < (NOW() - INTERVAL '30 seconds'))
      )
    FOR UPDATE SKIP LOCKED  -- Prevent race conditions
  LOOP
    -- If order has a driver assigned but hasn't accepted (30 seconds passed)
    IF v_order.driver_id IS NOT NULL AND v_order.driver_assigned_at IS NOT NULL THEN
      -- Remove the current driver assignment
      UPDATE orders
      SET 
        driver_id = NULL,
        driver_assigned_at = NULL,
        updated_at = NOW()
      WHERE id = v_order.id;

      -- Add driver to rejected list
      INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
      VALUES (v_order.id, v_order.driver_id, 'timeout')
      ON CONFLICT (order_id, driver_id) DO NOTHING;

      -- Update assignment record if exists
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_assignments') THEN
        UPDATE order_assignments
        SET status = 'timeout', responded_at = NOW()
        WHERE order_id = v_order.id 
          AND driver_id = v_order.driver_id 
          AND status = 'pending';
      END IF;
    END IF;

    -- Try to assign to next available driver
    v_assigned := auto_assign_order(v_order.id);

    IF v_assigned THEN
      -- Get the assigned driver ID
      SELECT o.driver_id INTO v_driver_id
      FROM orders o
      WHERE o.id = v_order.id;

      RETURN QUERY SELECT 
        v_order.id,
        'assigned'::TEXT,
        v_driver_id,
        format('Order assigned to driver %s', v_driver_id);
    ELSE
      -- Check if order was rejected
      SELECT o.status INTO v_order.status
      FROM orders o
      WHERE o.id = v_order.id;

      IF v_order.status = 'rejected' THEN
        RETURN QUERY SELECT 
          v_order.id,
          'rejected'::TEXT,
          NULL::UUID,
          'No available drivers - order rejected';
      ELSE
        RETURN QUERY SELECT 
          v_order.id,
          'pending'::TEXT,
          NULL::UUID,
          'Still pending - will retry on next check';
      END IF;
    END IF;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION check_and_assign_pending_orders IS 
  'Checks for pending orders that need assignment or reassignment (30 second threshold). 
   Called by the monitor-pending-orders edge function.';

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_and_assign_pending_orders() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION auto_assign_order(UUID) TO authenticated, anon;

-- Success message
DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'AUTO-ASSIGN FUNCTION UPDATED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'auto_assign_order now always sets';
  RAISE NOTICE 'driver_assigned_at timestamp.';
  RAISE NOTICE '';
  RAISE NOTICE 'check_and_assign_pending_orders()';
  RAISE NOTICE 'function created for edge function.';
  RAISE NOTICE '========================================';
END $$;

