-- =====================================================================================
-- DIAGNOSE EXPIRED ORDERS - Comprehensive Check
-- =====================================================================================
-- This query will show all pending orders and why they might or might not be expired
-- =====================================================================================

-- 1. Show ALL pending orders with their details
SELECT 
  'All Pending Orders' as check_type,
  id,
  customer_name,
  status,
  driver_id,
  driver_assigned_at,
  created_at,
  NOW() as current_time,
  CASE 
    WHEN driver_id IS NULL THEN '❌ No driver assigned'
    WHEN driver_assigned_at IS NULL THEN '❌ driver_assigned_at is NULL'
    WHEN driver_assigned_at IS NOT NULL THEN 
      '⏱️ ' || EXTRACT(EPOCH FROM (NOW() - driver_assigned_at))::INTEGER || ' seconds elapsed'
    ELSE 'Unknown'
  END as status_detail,
  CASE 
    WHEN driver_assigned_at IS NOT NULL THEN
      EXTRACT(EPOCH FROM (NOW() - driver_assigned_at))::INTEGER
    WHEN driver_id IS NOT NULL AND created_at < (NOW() - INTERVAL '30 seconds') THEN
      EXTRACT(EPOCH FROM (NOW() - created_at))::INTEGER
    ELSE NULL
  END as elapsed_seconds,
  CASE 
    WHEN driver_id IS NOT NULL AND driver_assigned_at IS NOT NULL AND driver_assigned_at < (NOW() - INTERVAL '30 seconds') 
    THEN '✅ EXPIRED - Should be processed (has driver_assigned_at)'
    WHEN driver_id IS NOT NULL AND driver_assigned_at IS NULL AND created_at < (NOW() - INTERVAL '30 seconds')
    THEN '✅ EXPIRED - Should be processed (no driver_assigned_at, using created_at)'
    WHEN driver_id IS NOT NULL AND driver_assigned_at IS NOT NULL AND driver_assigned_at >= (NOW() - INTERVAL '30 seconds')
    THEN '⏳ Not expired yet'
    WHEN driver_id IS NULL
    THEN '❌ No driver - cannot expire'
    ELSE '❓ Cannot determine'
  END as expiration_status
FROM orders
WHERE status = 'pending'
ORDER BY 
  CASE 
    WHEN driver_assigned_at IS NOT NULL THEN driver_assigned_at 
    ELSE created_at 
  END ASC;

-- 2. Count orders by status
SELECT 
  'Summary' as check_type,
  COUNT(*) FILTER (WHERE driver_id IS NULL) as pending_no_driver,
  COUNT(*) FILTER (WHERE driver_id IS NOT NULL AND driver_assigned_at IS NULL) as pending_with_driver_no_timestamp,
  COUNT(*) FILTER (WHERE driver_id IS NOT NULL AND driver_assigned_at IS NOT NULL) as pending_with_driver_and_timestamp,
  COUNT(*) FILTER (
    WHERE driver_id IS NOT NULL 
    AND driver_assigned_at IS NOT NULL 
    AND driver_assigned_at < (NOW() - INTERVAL '30 seconds')
  ) as expired_should_be_processed,
  COUNT(*) FILTER (
    WHERE driver_id IS NOT NULL 
    AND driver_assigned_at IS NOT NULL 
    AND driver_assigned_at >= (NOW() - INTERVAL '30 seconds')
  ) as not_expired_yet
FROM orders
WHERE status = 'pending';

-- 3. Show orders that should be expired but aren't being detected
SELECT 
  'MISSING driver_assigned_at' as issue_type,
  id,
  customer_name,
  driver_id,
  driver_assigned_at,
  created_at,
  'These orders have a driver but no driver_assigned_at timestamp' as reason
FROM orders
WHERE status = 'pending'
  AND driver_id IS NOT NULL
  AND driver_assigned_at IS NULL;

-- 4. Show orders that ARE expired (should be processed) - using improved logic
SELECT 
  'EXPIRED ORDERS' as issue_type,
  id,
  customer_name,
  driver_id,
  driver_assigned_at,
  created_at,
  CASE 
    WHEN driver_assigned_at IS NOT NULL 
    THEN EXTRACT(EPOCH FROM (NOW() - driver_assigned_at))::INTEGER
    ELSE EXTRACT(EPOCH FROM (NOW() - created_at))::INTEGER
  END as elapsed_seconds,
  CASE 
    WHEN driver_assigned_at IS NOT NULL THEN 'Has driver_assigned_at'
    ELSE 'Missing driver_assigned_at (using created_at)'
  END as detection_method,
  'These orders should be auto-rejected and reassigned' as reason
FROM orders
WHERE status = 'pending'
  AND driver_id IS NOT NULL
  AND (
    -- Standard case: driver_assigned_at exists and is expired
    (driver_assigned_at IS NOT NULL AND driver_assigned_at < (NOW() - INTERVAL '30 seconds'))
    OR
    -- Fallback case: driver_assigned_at is NULL but order was created > 30 seconds ago
    (driver_assigned_at IS NULL AND created_at < (NOW() - INTERVAL '30 seconds'))
  )
ORDER BY 
  CASE 
    WHEN driver_assigned_at IS NOT NULL THEN driver_assigned_at 
    ELSE created_at 
  END ASC;

-- 5. Test the auto_reject_expired_orders function
DO $$
DECLARE
  v_result INTEGER;
  v_before_count INTEGER;
  v_after_count INTEGER;
BEGIN
  -- Count expired orders before
  SELECT COUNT(*) INTO v_before_count
  FROM orders
  WHERE status = 'pending'
    AND driver_id IS NOT NULL
    AND driver_assigned_at IS NOT NULL
    AND driver_assigned_at < (NOW() - INTERVAL '30 seconds');
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TESTING auto_reject_expired_orders()';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Expired orders before: %', v_before_count;
  
  -- Call the function
  SELECT auto_reject_expired_orders() INTO v_result;
  
  -- Count expired orders after
  SELECT COUNT(*) INTO v_after_count
  FROM orders
  WHERE status = 'pending'
    AND driver_id IS NOT NULL
    AND driver_assigned_at IS NOT NULL
    AND driver_assigned_at < (NOW() - INTERVAL '30 seconds');
  
  RAISE NOTICE 'Function returned: % orders processed', v_result;
  RAISE NOTICE 'Expired orders after: %', v_after_count;
  
  IF v_result > 0 THEN
    RAISE NOTICE '✅ Function processed % orders successfully', v_result;
  ELSIF v_before_count > 0 AND v_result = 0 THEN
    RAISE WARNING '⚠️ Function returned 0 but there were % expired orders', v_before_count;
    RAISE WARNING '   This suggests the function is not working correctly';
  ELSE
    RAISE NOTICE '✅ No expired orders to process';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

-- 6. Check if driver_assigned_at is being set when drivers are assigned
SELECT 
  'Trigger Check' as check_type,
  EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'track_driver_assignment_trigger'
  ) as track_driver_assignment_trigger_exists,
  EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trg_update_timeout_state'
  ) as timeout_state_trigger_exists;

-- 7. Show trigger function definition
SELECT 
  p.proname as function_name,
  pg_get_functiondef(p.oid) as definition
FROM pg_proc p
WHERE p.proname IN ('track_driver_assignment', 'trigger_update_timeout_state')
ORDER BY p.proname;

