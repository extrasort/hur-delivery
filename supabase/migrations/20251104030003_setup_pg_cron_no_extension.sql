-- =====================================================================================
-- PG_CRON SETUP FOR MONITORING PENDING ORDERS (No Extension Creation)
-- =====================================================================================
-- This assumes pg_cron is already installed (which it is, since you have
-- process-scheduled-orders working). We just schedule the new job.
-- =====================================================================================

-- Step 1: Ensure the helper function exists
CREATE OR REPLACE FUNCTION call_monitor_pending_orders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Call the check_and_assign_pending_orders function
  -- This processes all pending orders that need attention
  PERFORM check_and_assign_pending_orders();
END;
$$;

-- Step 2: Remove any existing cron jobs with this name (if they exist)
DO $$
BEGIN
  -- Unschedule by jobname if it exists
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'monitor-pending-orders') THEN
    PERFORM cron.unschedule('monitor-pending-orders');
    RAISE NOTICE 'Unscheduled existing monitor-pending-orders job';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'monitor-pending-orders-db') THEN
    PERFORM cron.unschedule('monitor-pending-orders-db');
    RAISE NOTICE 'Unscheduled existing monitor-pending-orders-db job';
  END IF;
END $$;

-- Step 3: Schedule the function to run every minute
-- Note: pg_cron format is: minute hour day month weekday
-- Running every minute is sufficient - the function checks all orders
-- and processes those that meet the 30-second threshold
DO $$
BEGIN
  -- Check if pg_cron is available
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Schedule the job
    PERFORM cron.schedule(
      'monitor-pending-orders',
      '* * * * *',  -- Every minute
      'SELECT call_monitor_pending_orders();'
    );
    RAISE NOTICE 'Successfully scheduled monitor-pending-orders cron job';
  ELSE
    RAISE WARNING 'pg_cron extension not found. Job not scheduled.';
    RAISE WARNING 'Please enable pg_cron extension first.';
  END IF;
END $$;

-- Step 4: Verify the job is scheduled
DO $$
DECLARE
  v_job_count INTEGER;
  v_jobs TEXT;
BEGIN
  SELECT COUNT(*) INTO v_job_count
  FROM cron.job
  WHERE jobname LIKE 'monitor-pending-orders%';
  
  IF v_job_count > 0 THEN
    SELECT string_agg(jobname, ', ') INTO v_jobs
    FROM cron.job
    WHERE jobname LIKE 'monitor-pending-orders%';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'PG_CRON SETUP COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Scheduled % job(s): %', v_job_count, v_jobs;
    RAISE NOTICE '';
    RAISE NOTICE 'The function will run every minute';
    RAISE NOTICE 'and process all pending orders that';
    RAISE NOTICE 'need assignment or reassignment.';
    RAISE NOTICE '';
    RAISE NOTICE 'View scheduled jobs:';
    RAISE NOTICE '  SELECT * FROM cron.job WHERE jobname LIKE ''monitor-pending-orders%'';';
    RAISE NOTICE '';
    RAISE NOTICE 'View execution history:';
    RAISE NOTICE '  SELECT * FROM cron.job_run_details';
    RAISE NOTICE '  WHERE jobid IN (SELECT jobid FROM cron.job WHERE jobname LIKE ''monitor-pending-orders%'')';
    RAISE NOTICE '  ORDER BY start_time DESC LIMIT 10;';
    RAISE NOTICE '========================================';
  ELSE
    RAISE WARNING 'No jobs were scheduled. Check if pg_cron extension is enabled.';
  END IF;
END $$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION call_monitor_pending_orders() TO postgres;

COMMENT ON FUNCTION call_monitor_pending_orders IS 
  'Calls check_and_assign_pending_orders() to process pending orders.
   Scheduled to run every minute via pg_cron.';

