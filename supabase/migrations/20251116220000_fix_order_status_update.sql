-- Fix order status update function to return better error information
-- and handle edge cases more gracefully

DROP FUNCTION IF EXISTS update_order_status(UUID, TEXT, UUID);

CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id UUID,
  p_new_status TEXT,
  p_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_status TEXT;
  v_driver_id UUID;
  v_merchant_id UUID;
  v_user_role TEXT;
  v_delivery_fee DECIMAL;
  v_order_exists BOOLEAN;
  v_user_exists BOOLEAN;
BEGIN
  -- Log the attempt
  RAISE NOTICE 'Attempting to update order % to status % by user %', p_order_id, p_new_status, p_user_id;
  
  -- Check if order exists
  SELECT EXISTS(SELECT 1 FROM orders WHERE id = p_order_id) INTO v_order_exists;
  IF NOT v_order_exists THEN
    RAISE NOTICE 'Order % not found', p_order_id;
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_NOT_FOUND',
      'message', 'Order not found'
    );
  END IF;
  
  -- Check if user exists
  SELECT EXISTS(SELECT 1 FROM users WHERE id = p_user_id) INTO v_user_exists;
  IF NOT v_user_exists THEN
    RAISE NOTICE 'User % not found', p_user_id;
    RETURN json_build_object(
      'success', false,
      'error', 'USER_NOT_FOUND',
      'message', 'User not found'
    );
  END IF;
  
  -- Get order details
  SELECT status, driver_id, merchant_id, delivery_fee
  INTO v_current_status, v_driver_id, v_merchant_id, v_delivery_fee
  FROM orders
  WHERE id = p_order_id;
  
  -- Get user role
  SELECT role INTO v_user_role FROM users WHERE id = p_user_id;
  
  RAISE NOTICE 'Order status: %, Driver: %, Merchant: %, User role: %', 
    v_current_status, v_driver_id, v_merchant_id, v_user_role;
  
  -- Validate status transition
  IF v_current_status IN ('delivered', 'cancelled') THEN
    RAISE NOTICE 'Cannot update completed order with status %', v_current_status;
    RETURN json_build_object(
      'success', false,
      'error', 'ORDER_COMPLETED',
      'message', 'Cannot update completed order',
      'current_status', v_current_status
    );
  END IF;
  
  -- Validate permissions for drivers
  IF v_user_role = 'driver' THEN
    IF v_driver_id IS NULL THEN
      RAISE NOTICE 'Order % not assigned to any driver', p_order_id;
      RETURN json_build_object(
        'success', false,
        'error', 'NOT_ASSIGNED',
        'message', 'Order is not assigned to any driver',
        'driver_id', v_driver_id
      );
    END IF;
    
    IF v_driver_id != p_user_id THEN
      RAISE NOTICE 'Order assigned to % but user is %', v_driver_id, p_user_id;
      RETURN json_build_object(
        'success', false,
        'error', 'UNAUTHORIZED',
        'message', 'Order not assigned to this driver',
        'expected_driver', v_driver_id,
        'actual_driver', p_user_id
      );
    END IF;
  END IF;
  
  -- Validate permissions for merchants
  IF v_user_role = 'merchant' AND v_merchant_id != p_user_id THEN
    RAISE NOTICE 'Merchant mismatch: expected %, got %', v_merchant_id, p_user_id;
    RETURN json_build_object(
      'success', false,
      'error', 'UNAUTHORIZED',
      'message', 'Order does not belong to this merchant'
    );
  END IF;
  
  -- Update order status
  UPDATE orders
  SET 
    status = p_new_status,
    updated_at = NOW(),
    picked_up_at = CASE WHEN p_new_status = 'on_the_way' THEN NOW() ELSE picked_up_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE delivered_at END,
    cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN NOW() ELSE cancelled_at END
  WHERE id = p_order_id;
  
  RAISE NOTICE 'Order % updated to status %', p_order_id, p_new_status;
  
  -- Create earnings when order is delivered
  IF p_new_status = 'delivered' AND v_current_status != 'delivered' AND v_driver_id IS NOT NULL THEN
    INSERT INTO earnings (order_id, driver_id, amount, status)
    VALUES (p_order_id, v_driver_id, v_delivery_fee, 'pending')
    ON CONFLICT (order_id) DO NOTHING;
    RAISE NOTICE 'Earnings record created for driver %', v_driver_id;
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'message', 'Order status updated successfully',
    'old_status', v_current_status,
    'new_status', p_new_status
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error updating order: % %', SQLERRM, SQLSTATE;
    RETURN json_build_object(
      'success', false,
      'error', 'DATABASE_ERROR',
      'message', SQLERRM,
      'detail', SQLSTATE
    );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_order_status(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_order_status(UUID, TEXT, UUID) TO anon;

-- Add comment
COMMENT ON FUNCTION update_order_status IS 'Updates order status with proper validation and returns detailed error information';

