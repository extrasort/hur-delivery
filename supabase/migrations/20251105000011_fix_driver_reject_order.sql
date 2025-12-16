-- =====================================================================================
-- FIX: driver_reject_order function
-- =====================================================================================
-- This ensures driver_reject_order properly handles the case where no more drivers
-- are available (order will be marked as rejected by auto_assign_order)
-- Also fixes ON CONFLICT to use DELETE+INSERT pattern
-- =====================================================================================

CREATE OR REPLACE FUNCTION driver_reject_order(
  p_order_id UUID,
  p_driver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_status TEXT;
  v_assigned_driver UUID;
  v_response_time INTEGER;
  v_reassignment_success BOOLEAN;
BEGIN
  -- Get order details
  SELECT status, driver_id INTO v_order_status, v_assigned_driver
  FROM orders
  WHERE id = p_order_id;
  
  -- Validate order status
  IF v_order_status != 'pending' THEN
    RAISE NOTICE 'Order % is not pending (status: %)', p_order_id, v_order_status;
    RETURN FALSE;
  END IF;
  
  -- Validate driver assignment
  IF v_assigned_driver != p_driver_id THEN
    RAISE NOTICE 'Order % is not assigned to driver %', p_order_id, p_driver_id;
    RETURN FALSE;
  END IF;
  
  -- Calculate response time
  SELECT EXTRACT(EPOCH FROM (NOW() - driver_assigned_at))::INTEGER
  INTO v_response_time
  FROM orders
  WHERE id = p_order_id;
  
  -- Add driver to rejected list (using DELETE+INSERT instead of ON CONFLICT)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_rejected_drivers') THEN
    DELETE FROM order_rejected_drivers WHERE order_id = p_order_id AND driver_id = p_driver_id;
    INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
    VALUES (p_order_id, p_driver_id, 'manual_reject');
  END IF;
  
  -- Update assignment record if table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_assignments') THEN
    UPDATE order_assignments
    SET 
      status = 'rejected',
      responded_at = NOW(),
      response_time_seconds = v_response_time
    WHERE order_id = p_order_id AND driver_id = p_driver_id AND status = 'pending';
  END IF;
  
  -- Remove driver from order
  UPDATE orders
  SET 
    driver_id = NULL,
    driver_assigned_at = NULL,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Try to assign to next available driver
  -- This will mark order as rejected if no drivers are available
  v_reassignment_success := auto_assign_order(p_order_id);
  
  -- Check if order was marked as rejected (no drivers available)
  IF NOT v_reassignment_success THEN
    SELECT status INTO v_order_status
    FROM orders
    WHERE id = p_order_id;
    
    IF v_order_status = 'rejected' THEN
      RAISE NOTICE 'Driver % rejected order % after % seconds. No more drivers available - order marked as rejected.', 
        p_driver_id, p_order_id, v_response_time;
    ELSE
      RAISE NOTICE 'Driver % rejected order % after % seconds. Failed to reassign (order status: %).', 
        p_driver_id, p_order_id, v_response_time, v_order_status;
    END IF;
  ELSE
    RAISE NOTICE 'Driver % rejected order % after % seconds. Reassigned to next driver.', 
      p_driver_id, p_order_id, v_response_time;
  END IF;
  
  RETURN TRUE;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION driver_reject_order(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION driver_reject_order(UUID, UUID) TO anon;

-- Add comment
COMMENT ON FUNCTION driver_reject_order(UUID, UUID) IS 
  'Driver manually rejects an order. The order is automatically reassigned to the next available driver.
   If no drivers are available, the order is marked as rejected and the merchant is notified.';

-- Test and report
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DRIVER REJECT ORDER FIX APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '✅ driver_reject_order now:';
  RAISE NOTICE '   - Uses DELETE+INSERT instead of ON CONFLICT';
  RAISE NOTICE '   - Calls auto_assign_order which marks order as rejected if no drivers available';
  RAISE NOTICE '   - Provides better logging for rejected orders';
  RAISE NOTICE '';
  RAISE NOTICE 'Flow:';
  RAISE NOTICE '  1. Driver rejects order';
  RAISE NOTICE '  2. Driver removed from order';
  RAISE NOTICE '  3. auto_assign_order() called';
  RAISE NOTICE '  4. If no drivers available → order marked as rejected';
  RAISE NOTICE '  5. Merchant notified';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

