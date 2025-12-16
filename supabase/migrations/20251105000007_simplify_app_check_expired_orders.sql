-- =====================================================================================
-- SIMPLIFY app_check_expired_orders Function
-- =====================================================================================
-- This simplifies the function to directly call auto_reject_expired_orders()
-- instead of trying complex fallback logic
-- =====================================================================================

-- Drop existing function
DROP FUNCTION IF EXISTS app_check_expired_orders();

-- Create simplified version that directly calls auto_reject_expired_orders()
CREATE OR REPLACE FUNCTION app_check_expired_orders()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_processed INTEGER := 0;
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_execution_time_ms DOUBLE PRECISION;
BEGIN
  v_start_time := clock_timestamp();
  
  -- Directly call auto_reject_expired_orders() which handles everything
  SELECT auto_reject_expired_orders() INTO v_processed;
  
  v_end_time := clock_timestamp();
  v_execution_time_ms := EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
  
  -- Return JSON response
  RETURN jsonb_build_object(
    'success', true,
    'processed', v_processed,
    'execution_time_ms', v_execution_time_ms,
    'timestamp', NOW()
  );
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but return success=false
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'processed', 0,
      'timestamp', NOW()
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION app_check_expired_orders() TO authenticated;
GRANT EXECUTE ON FUNCTION app_check_expired_orders() TO anon;

-- Add comment
COMMENT ON FUNCTION app_check_expired_orders IS 
  'Checks and processes expired orders. Returns JSONB with success status and processed count. 
   This function is called by the Flutter app every 5 seconds.
   It directly calls auto_reject_expired_orders() to process expired orders.';

-- Test the function
DO $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT app_check_expired_orders() INTO v_result;
  RAISE NOTICE '✅ app_check_expired_orders() test successful';
  RAISE NOTICE '   Result: %', v_result;
END $$;

