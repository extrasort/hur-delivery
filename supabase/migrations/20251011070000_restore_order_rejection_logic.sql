-- Migration: Restore order rejection logic when no drivers are available
-- Fixes issue where orders remain pending indefinitely when all drivers reject them

-- ============================================================
-- UPDATE: Auto-Assign Order with proper rejection handling
-- ============================================================
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
  v_driver_id := find_next_available_driver(p_order_id, v_pickup_lat, v_pickup_lng, v_vehicle_type);
  
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
    -- Create assignment record
    INSERT INTO order_assignments (order_id, driver_id, status)
    VALUES (p_order_id, v_driver_id, 'pending');
    
    -- Notify driver (notification will be created by trigger)
    
    RAISE NOTICE 'Assigned order % (vehicle: %) to driver %', p_order_id, v_vehicle_type, v_driver_id;
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$;

COMMENT ON FUNCTION auto_assign_order(UUID) IS 
  'Automatically assigns an order to the next available driver with compatible vehicle type. Marks order as rejected if no compatible drivers are found.';

