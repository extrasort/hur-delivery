-- =====================================================================================
-- ORDER MONITORING TRIGGER (Alternative to pg_cron)
-- =====================================================================================
-- This trigger automatically checks for pending orders when orders are created/updated
-- Works in conjunction with the monitor-pending-orders edge function
-- =====================================================================================

-- Enhanced trigger function that checks pending orders
CREATE OR REPLACE FUNCTION trigger_check_pending_orders()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only check if order is pending
  IF (TG_OP = 'INSERT' AND NEW.status = 'pending') OR 
     (TG_OP = 'UPDATE' AND NEW.status = 'pending') THEN
    
    -- Non-blocking check - use advisory lock to prevent multiple simultaneous checks
    IF pg_try_advisory_lock(hashtext('check_pending_orders')) THEN
      BEGIN
        -- Check and process pending orders (non-blocking)
        PERFORM check_and_assign_pending_orders();
        
        -- Release the lock
        PERFORM pg_advisory_unlock(hashtext('check_pending_orders'));
      EXCEPTION
        WHEN OTHERS THEN
          -- Always release lock on error
          PERFORM pg_advisory_unlock(hashtext('check_pending_orders'));
          RAISE;
      END;
    END IF;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS check_pending_on_order_change ON orders;

-- Create trigger that fires on INSERT or UPDATE
CREATE TRIGGER check_pending_on_order_change
  AFTER INSERT OR UPDATE ON orders
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_check_pending_orders();

COMMENT ON FUNCTION trigger_check_pending_orders IS 
  'Automatically checks for pending orders that need assignment when orders are created or updated. 
   Uses advisory locks to prevent race conditions.';

-- Success message
DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'ORDER MONITORING TRIGGER CREATED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Trigger will automatically check';
  RAISE NOTICE 'pending orders on INSERT/UPDATE.';
  RAISE NOTICE '';
  RAISE NOTICE 'For best results, also call';
  RAISE NOTICE 'monitor-pending-orders edge function';
  RAISE NOTICE 'every second via external cron.';
  RAISE NOTICE '========================================';
END $$;

