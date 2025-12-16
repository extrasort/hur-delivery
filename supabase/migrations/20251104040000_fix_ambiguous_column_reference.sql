-- =====================================================================================
-- FIX AMBIGUOUS COLUMN REFERENCE IN check_and_assign_pending_orders
-- =====================================================================================
-- Fixes the "column reference driver_id is ambiguous" error by qualifying
-- all column references with table aliases
-- =====================================================================================

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
   Called by the monitor-pending-orders edge function. Fixed ambiguous column references.';

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_and_assign_pending_orders() TO authenticated, anon;

-- Success message
DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIXED AMBIGUOUS COLUMN REFERENCE';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'check_and_assign_pending_orders()';
  RAISE NOTICE 'now has qualified column references.';
  RAISE NOTICE '========================================';
END $$;

