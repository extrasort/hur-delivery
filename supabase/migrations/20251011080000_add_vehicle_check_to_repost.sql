-- Migration: Add vehicle type availability check to repost function
-- Prevents reposting orders if no drivers with required vehicle type are online

-- ============================================================
-- UPDATE: Repost Order with Vehicle Type Availability Check
-- ============================================================
CREATE OR REPLACE FUNCTION repost_order_with_increased_fee(
  p_order_id UUID,
  p_merchant_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_status TEXT;
  v_merchant_id UUID;
  v_current_fee DECIMAL;
  v_new_fee DECIMAL;
  v_repost_count INTEGER;
  v_vehicle_type TEXT;
  v_driver_count INTEGER;
BEGIN
  -- Get order details including vehicle type
  SELECT status, merchant_id, delivery_fee, repost_count, vehicle_type
  INTO v_order_status, v_merchant_id, v_current_fee, v_repost_count, v_vehicle_type
  FROM orders
  WHERE id = p_order_id;
  
  -- Validate merchant
  IF v_merchant_id != p_merchant_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'unauthorized',
      'message', 'Unauthorized: Order does not belong to this merchant'
    );
  END IF;
  
  -- Validate order status
  IF v_order_status != 'rejected' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'invalid_status',
      'message', format('Order is not rejected (status: %s)', v_order_status)
    );
  END IF;
  
  -- Check if there are drivers available with the required vehicle type
  SELECT COUNT(*) INTO v_driver_count
  FROM users
  WHERE role = 'driver'
    AND is_online = true
    AND manual_verified = true
    AND (
      v_vehicle_type IS NULL 
      OR vehicle_type IS NULL 
      OR vehicle_type = v_vehicle_type
      OR (vehicle_type = 'motorbike' AND v_vehicle_type = 'motorcycle')
      OR (vehicle_type = 'motorcycle' AND v_vehicle_type = 'motorbike')
    );
  
  IF v_driver_count = 0 THEN
    RAISE NOTICE 'Cannot repost order %: No drivers with vehicle type % are online', 
      p_order_id, v_vehicle_type;
    
    RETURN json_build_object(
      'success', false,
      'error', 'no_drivers',
      'message', format('No drivers with %s are currently online', COALESCE(v_vehicle_type, 'any vehicle')),
      'vehicle_type', v_vehicle_type,
      'driver_count', v_driver_count
    );
  END IF;
  
  -- Calculate new delivery fee (increase by 500 IQD)
  v_new_fee := v_current_fee + 500;
  
  -- Update order
  UPDATE orders
  SET 
    status = 'pending',
    delivery_fee = v_new_fee,
    original_delivery_fee = COALESCE(original_delivery_fee, v_current_fee),
    repost_count = v_repost_count + 1,
    driver_id = NULL,
    driver_assigned_at = NULL,
    rejected_at = NULL,
    rejection_reason = NULL,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Clear rejected drivers (give them another chance with higher fee)
  DELETE FROM order_rejected_drivers WHERE order_id = p_order_id;
  
  -- Try to auto-assign
  PERFORM auto_assign_order(p_order_id);
  
  RAISE NOTICE 'Order % reposted with new fee: % IQD (was % IQD). Available drivers: %', 
    p_order_id, v_new_fee, v_current_fee, v_driver_count;
  
  RETURN json_build_object(
    'success', true,
    'new_fee', v_new_fee,
    'old_fee', v_current_fee,
    'repost_count', v_repost_count + 1,
    'available_drivers', v_driver_count,
    'message', 'Order reposted successfully'
  );
END;
$$;

COMMENT ON FUNCTION repost_order_with_increased_fee(UUID, UUID) IS 
  'Reposts a rejected order with increased delivery fee. Checks for available drivers with compatible vehicle type before reposting. Returns JSON with success status and details.';

