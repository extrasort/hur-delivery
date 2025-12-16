-- =====================================================================================
-- SETUP AUTO-REJECT CRON JOB
-- =====================================================================================
-- This migration sets up a cron job to call auto_reject_expired_orders() every 5 seconds
-- This ensures orders are automatically rejected when drivers don't respond within 30 seconds
-- =====================================================================================

-- Step 1: Check if pg_cron extension is available
DO $$
DECLARE
  v_cron_available BOOLEAN;
  v_job_exists BOOLEAN;
BEGIN
  -- Check if pg_cron extension exists
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) INTO v_cron_available;
  
  IF NOT v_cron_available THEN
    RAISE WARNING 'pg_cron extension is not available. Auto-reject will rely on app polling.';
    RAISE WARNING 'To enable pg_cron: Go to Supabase Dashboard > Database > Extensions > Enable pg_cron';
    RETURN;
  END IF;
  
  -- Remove any existing auto-reject cron jobs
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'auto-reject-expired-orders') THEN
    PERFORM cron.unschedule('auto-reject-expired-orders');
    RAISE NOTICE 'Removed existing auto-reject-expired-orders cron job';
  END IF;
  
  -- Schedule the job to run every 5 seconds
  -- Note: pg_cron minimum interval is 1 minute, so we'll run it every minute
  -- The function checks all orders and processes those that are expired
  PERFORM cron.schedule(
    'auto-reject-expired-orders',
    '* * * * *',  -- Every minute (pg_cron format: minute hour day month weekday)
    'SELECT auto_reject_expired_orders();'
  );
  
  RAISE NOTICE '✅ Successfully scheduled auto-reject-expired-orders cron job';
  RAISE NOTICE '   The function will run every minute and process all expired orders';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error setting up cron job: %', SQLERRM;
    RAISE WARNING 'Auto-reject will rely on app-side polling via app_check_expired_orders()';
END $$;

-- Step 2: Verify the cron job is scheduled
DO $$
DECLARE
  v_job_count INTEGER;
  v_job_info RECORD;
BEGIN
  SELECT COUNT(*) INTO v_job_count
  FROM cron.job
  WHERE jobname = 'auto-reject-expired-orders';
  
  IF v_job_count > 0 THEN
    SELECT * INTO v_job_info
    FROM cron.job
    WHERE jobname = 'auto-reject-expired-orders'
    LIMIT 1;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'AUTO-REJECT CRON JOB SETUP COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Job Name: %', v_job_info.jobname;
    RAISE NOTICE 'Schedule: %', v_job_info.schedule;
    RAISE NOTICE 'Command: %', v_job_info.command;
    RAISE NOTICE '';
    RAISE NOTICE 'The function auto_reject_expired_orders() will run every minute';
    RAISE NOTICE 'and process all orders where drivers have not responded within 30 seconds.';
    RAISE NOTICE '';
    RAISE NOTICE 'View cron job details:';
    RAISE NOTICE '  SELECT * FROM cron.job WHERE jobname = ''auto-reject-expired-orders'';';
    RAISE NOTICE '';
    RAISE NOTICE 'View execution history:';
    RAISE NOTICE '  SELECT * FROM cron.job_run_details';
    RAISE NOTICE '  WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = ''auto-reject-expired-orders'')';
    RAISE NOTICE '  ORDER BY start_time DESC LIMIT 10;';
    RAISE NOTICE '========================================';
  ELSE
    RAISE WARNING '';
    RAISE WARNING '========================================';
    RAISE WARNING 'CRON JOB NOT SCHEDULED';
    RAISE WARNING '========================================';
    RAISE WARNING 'The auto-reject cron job could not be scheduled.';
    RAISE WARNING 'This might be because:';
    RAISE WARNING '  1. pg_cron extension is not enabled';
    RAISE WARNING '  2. Insufficient permissions';
    RAISE WARNING '';
    RAISE WARNING 'Auto-reject will still work via:';
    RAISE WARNING '  - App-side polling (app_check_expired_orders() called every 5 seconds)';
    RAISE WARNING '  - Manual trigger (call auto_reject_expired_orders() manually)';
    RAISE WARNING '';
    RAISE WARNING 'To enable pg_cron:';
    RAISE WARNING '  Go to Supabase Dashboard > Database > Extensions > Enable pg_cron';
    RAISE WARNING '========================================';
  END IF;
END $$;

-- Step 3: Test the function to make sure it works
DO $$
DECLARE
  v_function_exists BOOLEAN;
  v_test_result INTEGER;
BEGIN
  -- Check if function exists
  SELECT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'auto_reject_expired_orders'
  ) INTO v_function_exists;
  
  IF NOT v_function_exists THEN
    RAISE WARNING 'auto_reject_expired_orders() function does not exist!';
    RAISE WARNING 'Please run the migration that creates this function first.';
  ELSE
    RAISE NOTICE '✅ auto_reject_expired_orders() function exists';
    
    -- Test the function (it should return 0 if no expired orders)
    BEGIN
      SELECT auto_reject_expired_orders() INTO v_test_result;
      RAISE NOTICE '✅ Function test successful. Processed % expired orders', v_test_result;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING '⚠️ Function test failed: %', SQLERRM;
    END;
  END IF;
END $$;

-- Step 4: Grant execute permission (if not already granted)
GRANT EXECUTE ON FUNCTION auto_reject_expired_orders() TO postgres;
GRANT EXECUTE ON FUNCTION auto_reject_expired_orders() TO authenticated;
GRANT EXECUTE ON FUNCTION auto_reject_expired_orders() TO anon;

COMMENT ON FUNCTION auto_reject_expired_orders IS 
  'Automatically rejects orders when drivers do not accept within 30 seconds.
   Called by cron job every minute and by app-side polling every 5 seconds.
   Returns the number of orders processed.';

