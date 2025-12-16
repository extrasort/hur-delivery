-- =====================================================================================
-- SIMPLE PG_CRON SETUP FOR MONITORING PENDING ORDERS
-- =====================================================================================
-- This is the simplest approach - schedules the database function directly
-- No HTTP calls needed, no privilege conflicts
-- =====================================================================================

-- Step 1: Ensure pg_cron extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 2: Ensure the helper function exists (from previous migration)
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

-- Step 3: Remove any existing cron jobs with this name (if they exist)
DO $$
BEGIN
  -- Unschedule by jobname if it exists
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'monitor-pending-orders') THEN
    PERFORM cron.unschedule('monitor-pending-orders');
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'monitor-pending-orders-db') THEN
    PERFORM cron.unschedule('monitor-pending-orders-db');
  END IF;
END $$;

-- Step 4: Schedule the function to run every minute
-- Note: pg_cron standard format is: minute hour day month weekday
-- For more frequent checks, we'll schedule multiple jobs at different intervals
SELECT cron.schedule(
  'monitor-pending-orders',
  '* * * * *',  -- Every minute (cron format: minute hour day month weekday)
  $$SELECT call_monitor_pending_orders();$$
);

-- Step 5: Verify the job is scheduled
DO $$
DECLARE
  v_job_count INTEGER;
  v_jobs TEXT;
BEGIN
  SELECT COUNT(*) INTO v_job_count
  FROM cron.job
  WHERE jobname LIKE 'monitor-pending-orders%';
  
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
END $$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION call_monitor_pending_orders() TO postgres;

COMMENT ON FUNCTION call_monitor_pending_orders IS 
  'Calls check_and_assign_pending_orders() to process pending orders.
   Scheduled to run every minute via pg_cron.';

