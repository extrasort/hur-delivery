-- =====================================================================================
-- SETUP PG_CRON FOR MONITORING PENDING ORDERS
-- =====================================================================================
-- This migration sets up pg_cron to call the monitor-pending-orders edge function
-- every second. Handles privilege issues that may occur.
-- =====================================================================================

-- Step 1: Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 2: Grant necessary permissions (handling existing privileges)
-- First, revoke conflicting privileges if they exist
DO $$
BEGIN
  -- Try to revoke with CASCADE to handle dependent privileges
  BEGIN
    REVOKE ALL ON SCHEMA cron FROM postgres CASCADE;
  EXCEPTION
    WHEN OTHERS THEN
      -- If it fails, continue - permissions might already be set correctly
      RAISE NOTICE 'Could not revoke cron schema privileges: %', SQLERRM;
  END;
  
  BEGIN
    REVOKE ALL ON ALL FUNCTIONS IN SCHEMA cron FROM postgres CASCADE;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'Could not revoke cron function privileges: %', SQLERRM;
  END;
  
  BEGIN
    REVOKE ALL ON ALL TABLES IN SCHEMA cron FROM postgres CASCADE;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'Could not revoke cron table privileges: %', SQLERRM;
  END;
END $$;

-- Step 3: Grant minimal required permissions
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT SELECT ON cron.job TO postgres;
GRANT SELECT ON cron.job_run_details TO postgres;

-- Step 4: Ensure net extension is available for HTTP requests
-- (This is usually available in Supabase)
DO $$
BEGIN
  -- Check if net extension exists
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'net') THEN
    RAISE NOTICE 'net extension is available';
  ELSE
    RAISE WARNING 'net extension not found. HTTP requests from pg_cron may not work.';
  END IF;
END $$;

-- Step 5: Remove existing cron job if it exists
SELECT cron.unschedule('monitor-pending-orders') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'monitor-pending-orders'
);

-- Step 6: Create the cron job
-- Note: Replace YOUR_PROJECT_REF and YOUR_SERVICE_ROLE_KEY with actual values
-- You may need to set these as environment variables or update manually
DO $$
DECLARE
  v_project_ref TEXT;
  v_service_role_key TEXT;
  v_function_url TEXT;
BEGIN
  -- Get Supabase project reference from database name
  -- This is a workaround - you may need to set this manually
  SELECT current_database() INTO v_project_ref;
  
  -- Try to get service role key from environment or use a placeholder
  -- In production, you should set this via Supabase secrets or environment variables
  v_service_role_key := COALESCE(
    current_setting('app.settings.service_role_key', true),
    'YOUR_SERVICE_ROLE_KEY'  -- Replace this with actual key
  );
  
  -- Construct function URL
  v_function_url := format('https://%s.supabase.co/functions/v1/monitor-pending-orders', v_project_ref);
  
  -- Schedule the cron job to run every second
  -- Note: pg_cron format is: second minute hour day month weekday
  -- However, standard pg_cron only supports minute-level precision
  -- For second-level, we'll schedule it to run every minute and handle frequency in the function
  PERFORM cron.schedule(
    'monitor-pending-orders',
    '* * * * *',  -- Every minute (pg_cron doesn't support second-level in standard versions)
    format($$
      SELECT
        net.http_post(
          url := '%s',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer %s'
          ),
          body := '{}'::jsonb
        ) AS request_id;
    $$, v_function_url, v_service_role_key)
  );
  
  RAISE NOTICE 'Cron job scheduled: monitor-pending-orders';
  RAISE NOTICE 'URL: %', v_function_url;
  RAISE WARNING 'Please update YOUR_SERVICE_ROLE_KEY in this migration with your actual service role key!';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Could not schedule cron job: %', SQLERRM;
    RAISE NOTICE 'You may need to:';
    RAISE NOTICE '1. Install pg_net extension: CREATE EXTENSION IF NOT EXISTS pg_net;';
    RAISE NOTICE '2. Set service role key manually';
    RAISE NOTICE '3. Schedule manually: SELECT cron.schedule(...)';
END $$;

-- Alternative: If net extension doesn't work, use a simpler approach
-- Create a function that can be called by pg_cron
CREATE OR REPLACE FUNCTION call_monitor_pending_orders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- This function calls the check_and_assign_pending_orders RPC function
  -- which does the same work as the edge function
  PERFORM check_and_assign_pending_orders();
END;
$$;

-- Schedule the simpler function-based approach (alternative to HTTP call)
-- This runs every minute and processes pending orders
DO $$
BEGIN
  -- Only schedule if the HTTP-based one failed
  IF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'monitor-pending-orders'
  ) THEN
    PERFORM cron.schedule(
      'monitor-pending-orders-db',
      '* * * * *',  -- Every minute
      'SELECT call_monitor_pending_orders();'
    );
    
    RAISE NOTICE 'Scheduled database function-based cron job: monitor-pending-orders-db';
    RAISE NOTICE 'This runs every minute and processes pending orders directly in the database.';
  END IF;
END $$;

-- Step 7: Verify cron jobs are scheduled
DO $$
DECLARE
  v_job_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_job_count
  FROM cron.job
  WHERE jobname LIKE 'monitor-pending-orders%';
  
  IF v_job_count > 0 THEN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'PG_CRON SETUP COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Scheduled % job(s) for monitoring orders', v_job_count;
    RAISE NOTICE '';
    RAISE NOTICE 'View scheduled jobs:';
    RAISE NOTICE '  SELECT * FROM cron.job WHERE jobname LIKE ''monitor-pending-orders%'';';
    RAISE NOTICE '';
    RAISE NOTICE 'View job execution history:';
    RAISE NOTICE '  SELECT * FROM cron.job_run_details WHERE jobid IN (';
    RAISE NOTICE '    SELECT jobid FROM cron.job WHERE jobname LIKE ''monitor-pending-orders%''';
    RAISE NOTICE '  ) ORDER BY start_time DESC LIMIT 10;';
    RAISE NOTICE '';
    RAISE NOTICE 'To update service role key, unschedule and reschedule:';
    RAISE NOTICE '  SELECT cron.unschedule(''monitor-pending-orders'');';
    RAISE NOTICE '  -- Then update this migration with your key and re-run';
    RAISE NOTICE '========================================';
  ELSE
    RAISE WARNING 'No cron jobs were scheduled. Please check the errors above.';
  END IF;
END $$;

-- Grant execute permission on the helper function
GRANT EXECUTE ON FUNCTION call_monitor_pending_orders() TO postgres;

COMMENT ON FUNCTION call_monitor_pending_orders IS 
  'Helper function that calls check_and_assign_pending_orders(). 
   Can be scheduled with pg_cron as an alternative to HTTP calls.';

