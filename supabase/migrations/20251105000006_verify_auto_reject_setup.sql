-- =====================================================================================
-- VERIFY AUTO-REJECT SETUP
-- =====================================================================================
-- Run this to verify that auto-reject is properly configured
-- =====================================================================================

-- 1. Check if pg_cron extension is enabled
SELECT 
  'pg_cron Extension' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') 
    THEN '✅ Enabled' 
    ELSE '❌ Not Enabled' 
  END as status;

-- 2. Check if cron job is scheduled
SELECT 
  'Cron Job' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'auto-reject-expired-orders') 
    THEN '✅ Scheduled' 
    ELSE '❌ Not Scheduled' 
  END as status;

-- 3. Show cron job details
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
WHERE jobname = 'auto-reject-expired-orders';

-- 4. Check if auto_reject_expired_orders() function exists
SELECT 
  'Function Exists' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'auto_reject_expired_orders') 
    THEN '✅ Exists' 
    ELSE '❌ Missing' 
  END as status;

-- 5. Show function details
SELECT 
  p.proname as function_name,
  pg_get_function_result(p.oid) as return_type,
  pg_get_functiondef(p.oid) as definition
FROM pg_proc p
WHERE p.proname = 'auto_reject_expired_orders'
LIMIT 1;

-- 6. Check for expired orders that should be auto-rejected
SELECT 
  'Expired Orders' as check_type,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) > 0 THEN '⚠️ Found expired orders that need processing'
    ELSE '✅ No expired orders'
  END as status
FROM orders
WHERE status = 'pending'
  AND driver_id IS NOT NULL
  AND driver_assigned_at IS NOT NULL
  AND driver_assigned_at < (NOW() - INTERVAL '30 seconds');

-- 7. Show expired orders (if any)
SELECT 
  id,
  customer_name,
  driver_id,
  driver_assigned_at,
  EXTRACT(EPOCH FROM (NOW() - driver_assigned_at))::INTEGER as elapsed_seconds,
  created_at
FROM orders
WHERE status = 'pending'
  AND driver_id IS NOT NULL
  AND driver_assigned_at IS NOT NULL
  AND driver_assigned_at < (NOW() - INTERVAL '30 seconds')
ORDER BY driver_assigned_at ASC
LIMIT 10;

-- 8. Test the function manually
DO $$
DECLARE
  v_result INTEGER;
BEGIN
  SELECT auto_reject_expired_orders() INTO v_result;
  RAISE NOTICE 'Manual test: auto_reject_expired_orders() returned %', v_result;
  IF v_result > 0 THEN
    RAISE NOTICE '✅ Function is working! Processed % expired orders', v_result;
  ELSE
    RAISE NOTICE '✅ Function is working! No expired orders to process';
  END IF;
END $$;

-- 9. Check recent cron job executions
SELECT 
  jobid,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'auto-reject-expired-orders' LIMIT 1)
ORDER BY start_time DESC
LIMIT 10;

-- 10. Summary
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'AUTO-REJECT SETUP VERIFICATION';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'If cron job is scheduled:';
  RAISE NOTICE '  - It will run every minute';
  RAISE NOTICE '  - It will process all expired orders';
  RAISE NOTICE '';
  RAISE NOTICE 'If cron job is NOT scheduled:';
  RAISE NOTICE '  - Auto-reject will still work via app polling';
  RAISE NOTICE '  - The app calls app_check_expired_orders() every 5 seconds';
  RAISE NOTICE '';
  RAISE NOTICE 'To manually test:';
  RAISE NOTICE '  SELECT auto_reject_expired_orders();';
  RAISE NOTICE '';
  RAISE NOTICE 'To view cron job execution history:';
  RAISE NOTICE '  SELECT * FROM cron.job_run_details';
  RAISE NOTICE '  WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = ''auto-reject-expired-orders'')';
  RAISE NOTICE '  ORDER BY start_time DESC LIMIT 10;';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

