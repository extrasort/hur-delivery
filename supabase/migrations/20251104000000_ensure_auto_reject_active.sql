-- =====================================================================================
-- ENSURE AUTO-REJECT SYSTEM IS ACTIVE
-- =====================================================================================
-- This migration ensures the auto-reject trigger is active and working
-- It will auto-reject orders when drivers don't accept within 30 seconds
-- =====================================================================================

-- Ensure the trigger exists and is active
DROP TRIGGER IF EXISTS check_expired_orders_on_change ON orders;
CREATE TRIGGER check_expired_orders_on_change
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_check_expired_orders();

-- Verify the function exists (recreate if needed)
CREATE OR REPLACE FUNCTION trigger_check_expired_orders()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Asynchronously check for expired orders
  -- This won't block the main operation
  PERFORM check_expired_orders();
  
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Ensure check_expired_orders function exists
CREATE OR REPLACE FUNCTION check_expired_orders()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_has_expired BOOLEAN;
  v_processed INTEGER;
BEGIN
  -- Quick check if there are any expired orders (30 seconds timeout)
  SELECT EXISTS(
    SELECT 1 
    FROM orders
    WHERE status = 'pending'
      AND driver_id IS NOT NULL
      AND driver_assigned_at IS NOT NULL
      AND driver_assigned_at < (NOW() - INTERVAL '30 seconds')
    LIMIT 1
  ) INTO v_has_expired;
  
  -- If there are expired orders, process them
  IF v_has_expired THEN
    SELECT auto_reject_expired_orders() INTO v_processed;
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$$;

-- Ensure auto_reject_expired_orders function exists
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
    
    -- Update assignment record if table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_assignments') THEN
      UPDATE order_assignments
      SET status = 'timeout', responded_at = NOW()
      WHERE order_id = expired_order.id 
        AND driver_id = expired_order.driver_id 
        AND status = 'pending';
    END IF;
    
    -- Remove driver from order
    UPDATE orders
    SET 
      driver_id = NULL,
      driver_assigned_at = NULL,
      updated_at = NOW()
    WHERE id = expired_order.id;
    
    -- Try to assign to next available driver (if function exists)
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'auto_assign_order') THEN
      PERFORM auto_assign_order(expired_order.id);
    END IF;
    
    v_count := v_count + 1;
    
    RAISE NOTICE 'Driver % timed out on order %. Reassigning...', 
      expired_order.driver_id, expired_order.id;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION auto_reject_expired_orders() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION check_expired_orders() TO authenticated, anon;

-- Add comment
COMMENT ON FUNCTION auto_reject_expired_orders IS 
  'Auto-rejects orders when drivers do not accept within 30 seconds of assignment. Called by trigger on order table changes.';

COMMENT ON FUNCTION check_expired_orders IS 
  'Lightweight function to check and process expired orders. Called by trigger on order table changes.';

-- Success message
DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'AUTO-REJECT SYSTEM ACTIVATED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Orders will be auto-rejected if drivers';
  RAISE NOTICE 'do not accept within 30 seconds.';
  RAISE NOTICE 'Trigger is active on orders table.';
  RAISE NOTICE '========================================';
END $$;

