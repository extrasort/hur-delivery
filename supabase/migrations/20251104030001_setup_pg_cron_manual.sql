-- =====================================================================================
-- MANUAL PG_CRON SETUP INSTRUCTIONS
-- =====================================================================================
-- If the automatic migration fails, use these SQL commands manually
-- Run them in the Supabase SQL Editor
-- =====================================================================================

-- Step 1: Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 2: Enable pg_net extension (for HTTP requests)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Step 3: Get your project reference
-- You can find this in your Supabase project URL: https://[PROJECT_REF].supabase.co
-- Replace 'YOUR_PROJECT_REF' below with your actual project reference

-- Step 4: Get your service role key
-- Go to: Supabase Dashboard > Settings > API > Service Role Key (secret)
-- Replace 'YOUR_SERVICE_ROLE_KEY' below with your actual service role key

-- Step 5: Schedule the cron job
-- Option A: HTTP-based (calls edge function)
SELECT cron.schedule(
  'monitor-pending-orders',
  '* * * * *',  -- Every minute (pg_cron standard precision)
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/monitor-pending-orders',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      ),
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

-- Option B: Database function-based (runs directly in database, no HTTP)
-- This is simpler and doesn't require pg_net
SELECT cron.schedule(
  'monitor-pending-orders-db',
  '* * * * *',  -- Every minute
  'SELECT call_monitor_pending_orders();'
);

-- Step 6: Verify it's scheduled
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active
FROM cron.job
WHERE jobname LIKE 'monitor-pending-orders%';

-- Step 7: View execution history
SELECT 
  jobid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
WHERE jobid IN (
  SELECT jobid FROM cron.job WHERE jobname LIKE 'monitor-pending-orders%'
)
ORDER BY start_time DESC
LIMIT 20;

-- To unschedule:
-- SELECT cron.unschedule('monitor-pending-orders');
-- SELECT cron.unschedule('monitor-pending-orders-db');

-- To update schedule (e.g., every 5 seconds would need multiple jobs):
-- For more frequent checks, schedule multiple jobs with different offsets:
-- SELECT cron.schedule('monitor-pending-orders-1', '0-59/5 * * * *', '...');  -- Every 5 seconds
-- SELECT cron.schedule('monitor-pending-orders-2', '1-59/5 * * * *', '...');
-- SELECT cron.schedule('monitor-pending-orders-3', '2-59/5 * * * *', '...');
-- SELECT cron.schedule('monitor-pending-orders-4', '3-59/5 * * * *', '...');
-- SELECT cron.schedule('monitor-pending-orders-5', '4-59/5 * * * *', '...');

