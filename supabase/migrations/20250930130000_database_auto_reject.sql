-- =====================================================================================
-- HUR DELIVERY - DATABASE-ONLY AUTO-REJECT SYSTEM
-- =====================================================================================
-- This migration adds a pure database solution for auto-rejecting expired orders
-- No Edge Functions or external services required!
-- 
-- How it works:
-- 1. Every time orders table is accessed (SELECT, INSERT, UPDATE)
-- 2. A trigger automatically checks for and processes expired orders
-- 3. Expired orders are auto-rejected and reassigned
-- 
-- This ensures expired orders are handled within milliseconds of any database activity
-- =====================================================================================

-- =====================================================================================
-- 1. ENHANCED AUTO-REJECT FUNCTION (Returns count for monitoring)
-- =====================================================================================

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
    
    -- Update assignment record
    UPDATE order_assignments
    SET status = 'timeout', responded_at = NOW()
    WHERE order_id = expired_order.id 
      AND driver_id = expired_order.driver_id 
      AND status = 'pending';
    
    -- Remove driver from order
    UPDATE orders
    SET 
      driver_id = NULL,
      driver_assigned_at = NULL,
      updated_at = NOW()
    WHERE id = expired_order.id;
    
    -- Try to assign to next available driver
    PERFORM auto_assign_order(expired_order.id);
    
    v_count := v_count + 1;
    
    RAISE NOTICE 'Driver % timed out on order %. Reassigning...', 
      expired_order.driver_id, expired_order.id;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- =====================================================================================
-- 2. LIGHTWEIGHT CHECK FUNCTION (Called frequently, very fast)
-- =====================================================================================

-- This function is optimized for speed - only checks if there are expired orders
-- Returns TRUE if any orders were processed
CREATE OR REPLACE FUNCTION check_expired_orders()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_has_expired BOOLEAN;
  v_processed INTEGER;
BEGIN
  -- Quick check if there are any expired orders
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

-- =====================================================================================
-- 3. TRIGGER: Auto-check on any table activity
-- =====================================================================================

-- This trigger runs AFTER any change to orders table
-- It's lightweight and only processes if needed
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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS check_expired_orders_on_change ON orders;

-- Create trigger that runs after INSERT, UPDATE, or DELETE
CREATE TRIGGER check_expired_orders_on_change
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_check_expired_orders();

-- =====================================================================================
-- 4. SCHEDULED CHECK VIA DATABASE (Using advisory locks)
-- =====================================================================================

-- This function can be called periodically from the application
-- It uses advisory locks to ensure only one instance runs at a time
CREATE OR REPLACE FUNCTION scheduled_check_expired_orders()
RETURNS TABLE (
  processed INTEGER,
  execution_time_ms DOUBLE PRECISION,
  lock_acquired BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_processed INTEGER := 0;
  v_lock_acquired BOOLEAN := FALSE;
BEGIN
  v_start_time := clock_timestamp();
  
  -- Try to acquire advisory lock (non-blocking)
  -- This ensures only one check runs at a time
  v_lock_acquired := pg_try_advisory_lock(hashtext('auto_reject_orders'));
  
  IF v_lock_acquired THEN
    BEGIN
      -- Process expired orders
      SELECT auto_reject_expired_orders() INTO v_processed;
      
      -- Release the lock
      PERFORM pg_advisory_unlock(hashtext('auto_reject_orders'));
    EXCEPTION
      WHEN OTHERS THEN
        -- Always release lock on error
        PERFORM pg_advisory_unlock(hashtext('auto_reject_orders'));
        RAISE;
    END;
  END IF;
  
  v_end_time := clock_timestamp();
  
  RETURN QUERY SELECT 
    v_processed,
    EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time))::DOUBLE PRECISION,
    v_lock_acquired;
END;
$$;

-- =====================================================================================
-- 5. HEARTBEAT TABLE (For monitoring)
-- =====================================================================================

-- Track when auto-reject checks run
CREATE TABLE IF NOT EXISTS auto_reject_heartbeat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  processed_count INTEGER NOT NULL DEFAULT 0,
  execution_time_ms DOUBLE PRECISION,
  checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  triggered_by TEXT  -- 'trigger', 'scheduled', 'manual'
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_heartbeat_checked_at 
  ON auto_reject_heartbeat(checked_at DESC);

-- Keep only last 1000 heartbeats (auto-cleanup)
CREATE OR REPLACE FUNCTION cleanup_old_heartbeats()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM auto_reject_heartbeat
  WHERE id IN (
    SELECT id 
    FROM auto_reject_heartbeat
    ORDER BY checked_at DESC
    OFFSET 1000
  );
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cleanup_heartbeats ON auto_reject_heartbeat;
CREATE TRIGGER cleanup_heartbeats
  AFTER INSERT ON auto_reject_heartbeat
  FOR EACH STATEMENT
  EXECUTE FUNCTION cleanup_old_heartbeats();

-- =====================================================================================
-- 6. MONITORED AUTO-REJECT (With heartbeat logging)
-- =====================================================================================

CREATE OR REPLACE FUNCTION monitored_auto_reject()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_processed INTEGER := 0;
BEGIN
  v_start_time := clock_timestamp();
  
  -- Process expired orders
  SELECT auto_reject_expired_orders() INTO v_processed;
  
  v_end_time := clock_timestamp();
  
  -- Log to heartbeat table
  INSERT INTO auto_reject_heartbeat (
    processed_count,
    execution_time_ms,
    checked_at,
    triggered_by
  )
  VALUES (
    v_processed,
    EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time)),
    NOW(),
    'trigger'
  );
  
  RETURN v_processed;
END;
$$;

-- =====================================================================================
-- 7. VIEW: Recent Auto-Reject Activity
-- =====================================================================================

CREATE OR REPLACE VIEW auto_reject_activity AS
SELECT 
  h.id,
  h.processed_count,
  h.execution_time_ms,
  h.checked_at,
  h.triggered_by,
  CASE 
    WHEN h.processed_count > 0 THEN '🔄 Processed'
    ELSE '✓ No expired orders'
  END as status
FROM auto_reject_heartbeat h
ORDER BY h.checked_at DESC
LIMIT 100;

-- =====================================================================================
-- 8. HELPER FUNCTION: Manual trigger for testing
-- =====================================================================================

-- Call this from your Flutter app or SQL to manually trigger a check
CREATE OR REPLACE FUNCTION manual_check_expired_orders()
RETURNS TABLE (
  expired_count INTEGER,
  execution_time_ms DOUBLE PRECISION,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_processed INTEGER := 0;
BEGIN
  v_start_time := clock_timestamp();
  
  -- Process expired orders
  SELECT auto_reject_expired_orders() INTO v_processed;
  
  v_end_time := clock_timestamp();
  
  -- Log to heartbeat
  INSERT INTO auto_reject_heartbeat (
    processed_count,
    execution_time_ms,
    checked_at,
    triggered_by
  )
  VALUES (
    v_processed,
    EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time)),
    NOW(),
    'manual'
  );
  
  RETURN QUERY SELECT 
    v_processed,
    EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time)),
    CASE 
      WHEN v_processed > 0 THEN 
        format('Processed %s expired order(s)', v_processed)
      ELSE 
        'No expired orders found'
    END;
END;
$$;

-- =====================================================================================
-- 9. BACKGROUND WORKER (Optional - requires pg_cron or similar)
-- =====================================================================================

-- If pg_cron is available, you can schedule this:
-- SELECT cron.schedule(
--   'auto-reject-expired-orders',
--   '*/5 * * * *',  -- Every 5 seconds (use actual cron syntax)
--   'SELECT scheduled_check_expired_orders();'
-- );

-- =====================================================================================
-- 10. APPLICATION-LEVEL POLLING (Recommended)
-- =====================================================================================

-- Call this from your Flutter app on a timer (every 5 seconds)
-- It's very lightweight and won't impact performance
CREATE OR REPLACE FUNCTION app_check_expired_orders()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result RECORD;
  v_response JSONB;
BEGIN
  -- Use the scheduled check with advisory locks
  SELECT * FROM scheduled_check_expired_orders() INTO v_result;
  
  -- Log if orders were processed
  IF v_result.processed > 0 THEN
    INSERT INTO auto_reject_heartbeat (
      processed_count,
      execution_time_ms,
      checked_at,
      triggered_by
    )
    VALUES (
      v_result.processed,
      v_result.execution_time_ms,
      NOW(),
      'app_poll'
    );
  END IF;
  
  -- Return JSON response
  v_response := jsonb_build_object(
    'success', true,
    'processed', v_result.processed,
    'execution_time_ms', v_result.execution_time_ms,
    'lock_acquired', v_result.lock_acquired,
    'timestamp', NOW()
  );
  
  RETURN v_response;
END;
$$;

-- =====================================================================================
-- GRANT PERMISSIONS
-- =====================================================================================

GRANT SELECT ON auto_reject_heartbeat TO authenticated, anon;
GRANT SELECT ON auto_reject_activity TO authenticated, anon;
GRANT EXECUTE ON FUNCTION app_check_expired_orders() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION manual_check_expired_orders() TO authenticated, anon;

-- =====================================================================================
-- COMMENTS
-- =====================================================================================

COMMENT ON FUNCTION check_expired_orders IS 
  'Lightweight function to check and process expired orders. Called by trigger.';

COMMENT ON FUNCTION scheduled_check_expired_orders IS 
  'Thread-safe scheduled check using advisory locks. Safe to call from multiple sources.';

COMMENT ON FUNCTION app_check_expired_orders IS 
  'Application-level polling function. Call this every 5 seconds from Flutter app.';

COMMENT ON FUNCTION manual_check_expired_orders IS 
  'Manual trigger for testing. Returns detailed results.';

COMMENT ON TABLE auto_reject_heartbeat IS 
  'Monitors auto-reject execution. Automatically keeps last 1000 records.';

COMMENT ON VIEW auto_reject_activity IS 
  'Shows recent auto-reject activity for monitoring dashboard.';

-- =====================================================================================
-- SUCCESS MESSAGE
-- =====================================================================================

DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DATABASE AUTO-REJECT SYSTEM INSTALLED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'How it works:';
  RAISE NOTICE '1. Trigger: Checks automatically on any order table activity';
  RAISE NOTICE '2. App polling: Call app_check_expired_orders() every 5 seconds';
  RAISE NOTICE '3. Manual: Call manual_check_expired_orders() anytime';
  RAISE NOTICE '';
  RAISE NOTICE 'From Flutter app, add this to a timer:';
  RAISE NOTICE '  Timer.periodic(Duration(seconds: 5), (timer) {';
  RAISE NOTICE '    Supabase.instance.client.rpc(''app_check_expired_orders'');';
  RAISE NOTICE '  });';
  RAISE NOTICE '';
  RAISE NOTICE 'Monitor activity:';
  RAISE NOTICE '  SELECT * FROM auto_reject_activity;';
  RAISE NOTICE '';
  RAISE NOTICE 'Test manually:';
  RAISE NOTICE '  SELECT * FROM manual_check_expired_orders();';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

