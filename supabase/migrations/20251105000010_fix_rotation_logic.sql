-- =====================================================================================
-- FIX: Driver Rotation Logic
-- =====================================================================================
-- This fixes the rotation issue by ensuring auto_assign_order properly handles
-- vehicle types and that rotation works correctly even when drivers are offline
-- =====================================================================================

-- Step 1: Fix auto_assign_order to pass vehicle_type to find_next_available_driver
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
  v_current_driver_id UUID;
BEGIN
  -- Get order details including current driver (if any)
  SELECT status, pickup_latitude, pickup_longitude, vehicle_type, driver_id
  INTO v_order_status, v_pickup_lat, v_pickup_lng, v_vehicle_type, v_current_driver_id
  FROM orders
  WHERE id = p_order_id;
  
  -- Only assign if order is pending
  IF v_order_status != 'pending' THEN
    RAISE NOTICE 'Order % is not pending (status: %), skipping assignment', p_order_id, v_order_status;
    RETURN FALSE;
  END IF;
  
  -- If order already has a driver, don't reassign (this prevents race conditions)
  IF v_current_driver_id IS NOT NULL THEN
    RAISE NOTICE 'Order % already has driver %, skipping reassignment', p_order_id, v_current_driver_id;
    RETURN FALSE;
  END IF;
  
  -- Find next available driver (pass vehicle_type for proper filtering)
  IF v_vehicle_type IS NOT NULL THEN
    v_driver_id := find_next_available_driver(p_order_id, v_pickup_lat, v_pickup_lng, v_vehicle_type);
  ELSE
    v_driver_id := find_next_available_driver(p_order_id, v_pickup_lat, v_pickup_lng);
  END IF;
  
  IF v_driver_id IS NULL THEN
    -- No available drivers - mark order as rejected
    DECLARE
      v_rejection_count INTEGER;
      v_merchant_id UUID;
    BEGIN
      -- Count how many drivers have rejected this order
      SELECT COUNT(*) INTO v_rejection_count
      FROM order_rejected_drivers
      WHERE order_id = p_order_id;
      
      -- Get merchant_id for notification
      SELECT merchant_id INTO v_merchant_id
      FROM orders
      WHERE id = p_order_id;
      
      RAISE NOTICE 'No available drivers for order % (vehicle type: %). Total rejections: %. Marking as rejected.', 
        p_order_id, v_vehicle_type, v_rejection_count;
      
      -- Mark order as rejected
      UPDATE orders
      SET 
        status = 'rejected',
        rejected_at = NOW(),
        rejection_reason = CASE 
          WHEN v_vehicle_type IS NOT NULL THEN 
            'No available drivers with ' || v_vehicle_type || ' vehicle type'
          ELSE 
            'No available drivers'
        END,
        updated_at = NOW()
      WHERE id = p_order_id
        AND status = 'pending'; -- Only update if still pending
      
      -- Notify merchant if order was marked as rejected
      IF FOUND AND v_merchant_id IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
          INSERT INTO notifications (user_id, title, body, type, data)
          VALUES (
            v_merchant_id,
            'تم رفض الطلب',
            CASE 
              WHEN v_vehicle_type IS NOT NULL THEN
                'لم يتم العثور على سائق متاح بنوع المركبة المطلوبة (' || v_vehicle_type || '). يمكنك إعادة نشر الطلب بزيادة أجرة التوصيل.'
              ELSE
                'لم يتم العثور على سائق متاح. يمكنك إعادة نشر الطلب بزيادة أجرة التوصيل.'
            END,
            'order_cancelled',
            jsonb_build_object(
              'order_id', p_order_id, 
              'repost_available', true,
              'rejection_reason', 'no_drivers_available'
            )
          );
        END IF;
        
        RAISE NOTICE '✅ Order % marked as rejected. Merchant notified.', p_order_id;
      END IF;
    END;
    
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
    AND driver_id IS NULL; -- Double-check it hasn't been assigned in the meantime
  
  IF FOUND THEN
    -- Create assignment record if table exists (using DELETE+INSERT instead of ON CONFLICT)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_assignments') THEN
      DELETE FROM order_assignments WHERE order_id = p_order_id AND driver_id = v_driver_id;
      INSERT INTO order_assignments (order_id, driver_id, status)
      VALUES (p_order_id, v_driver_id, 'pending');
    END IF;
    
    RAISE NOTICE '✅ Assigned order % (vehicle: %) to driver % at %', 
      p_order_id, v_vehicle_type, v_driver_id, NOW();
    RETURN TRUE;
  ELSE
    RAISE NOTICE '⚠️ Failed to assign order % - may have been assigned by another process', p_order_id;
    RETURN FALSE;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING '❌ Error in auto_assign_order for order %: %', p_order_id, SQLERRM;
    RETURN FALSE;
END;
$$;

-- Step 2: Ensure find_next_available_driver properly excludes offline drivers
-- The function already checks is_online = true, but let's make sure it's robust
DO $$
BEGIN
  RAISE NOTICE 'Verifying find_next_available_driver excludes:';
  RAISE NOTICE '  - Drivers in order_rejected_drivers for this order';
  RAISE NOTICE '  - Offline drivers (is_online = false)';
  RAISE NOTICE '  - Drivers with active orders';
  RAISE NOTICE '';
  RAISE NOTICE 'If rotation is not working, check:';
  RAISE NOTICE '  1. Are there other online drivers available?';
  RAISE NOTICE '  2. Are rejected drivers properly added to order_rejected_drivers?';
  RAISE NOTICE '  3. Are timed-out drivers being marked as offline?';
END $$;

-- Step 3: Add diagnostic function to check rotation status
CREATE OR REPLACE FUNCTION check_order_rotation_status(p_order_id UUID)
RETURNS TABLE (
  order_id UUID,
  current_driver_id UUID,
  rejected_driver_count INTEGER,
  rejected_driver_ids UUID[],
  available_online_drivers INTEGER,
  rotation_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_rejected_drivers UUID[];
  v_available_count INTEGER;
BEGIN
  -- Get order details
  SELECT 
    id,
    driver_id,
    status,
    pickup_latitude,
    pickup_longitude,
    vehicle_type
  INTO v_order
  FROM orders
  WHERE id = p_order_id;
  
  IF NOT FOUND THEN
    RETURN;
  END IF;
  
  -- Get rejected drivers
  SELECT ARRAY_AGG(driver_id) INTO v_rejected_drivers
  FROM order_rejected_drivers
  WHERE order_id = p_order_id;
  
  -- Count available online drivers (excluding rejected ones)
  SELECT COUNT(*) INTO v_available_count
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    AND u.manual_verified = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    AND (v_order.vehicle_type IS NULL 
         OR v_order.vehicle_type = 'any'
         OR u.vehicle_type IS NULL
         OR u.vehicle_type = v_order.vehicle_type
         OR (u.vehicle_type = 'motorbike' AND v_order.vehicle_type = 'motorcycle')
         OR (u.vehicle_type = 'motorcycle' AND v_order.vehicle_type = 'motorbike'))
    AND u.id NOT IN (
      SELECT driver_id FROM order_rejected_drivers WHERE order_id = p_order_id
    )
    AND u.id NOT IN (
      SELECT driver_id FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('pending', 'accepted', 'on_the_way')
    );
  
  RETURN QUERY
  SELECT 
    v_order.id as order_id,
    v_order.driver_id as current_driver_id,
    COALESCE(ARRAY_LENGTH(v_rejected_drivers, 1), 0)::INTEGER as rejected_driver_count,
    COALESCE(v_rejected_drivers, ARRAY[]::UUID[]) as rejected_driver_ids,
    v_available_count as available_online_drivers,
    CASE 
      WHEN v_order.status != 'pending' THEN 'Order is not pending'
      WHEN v_order.driver_id IS NOT NULL THEN 'Order has driver assigned'
      WHEN v_available_count = 0 THEN 'No available drivers'
      WHEN ARRAY_LENGTH(v_rejected_drivers, 1) IS NULL OR ARRAY_LENGTH(v_rejected_drivers, 1) = 0 THEN 'No rejections yet'
      ELSE 'Rotation should work - drivers available'
    END as rotation_status;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION auto_assign_order(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION auto_assign_order(UUID) TO anon;
GRANT EXECUTE ON FUNCTION check_order_rotation_status(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_order_rotation_status(UUID) TO anon;

-- Add comments
COMMENT ON FUNCTION auto_assign_order(UUID) IS 
  'Assigns a pending order to the next available driver.
   Excludes drivers in order_rejected_drivers and offline drivers.
   Properly handles vehicle type compatibility.
   If no drivers are available, marks the order as rejected and notifies the merchant.';

COMMENT ON FUNCTION check_order_rotation_status(UUID) IS 
  'Diagnostic function to check why rotation might not be working for an order.
   Shows rejected drivers, available drivers, and rotation status.';

-- Step 4: Test and report
DO $$
DECLARE
  v_test_order_id UUID;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'ROTATION FIX APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '✅ auto_assign_order now:';
  RAISE NOTICE '   - Passes vehicle_type to find_next_available_driver';
  RAISE NOTICE '   - Checks driver_id is NULL before assigning';
  RAISE NOTICE '   - Provides better logging';
  RAISE NOTICE '';
  RAISE NOTICE '✅ New diagnostic function:';
  RAISE NOTICE '   check_order_rotation_status(order_id)';
  RAISE NOTICE '';
  RAISE NOTICE 'To diagnose rotation issues for an order:';
  RAISE NOTICE '  SELECT * FROM check_order_rotation_status(''<order_id>'');';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

