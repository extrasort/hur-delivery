-- =====================================================================================
-- FIX: app_check_expired_orders Function
-- =====================================================================================
-- This migration ensures the app_check_expired_orders function exists and works correctly
-- It handles both JSONB and void return types for compatibility
-- =====================================================================================

-- Drop existing function to avoid conflicts
DROP FUNCTION IF EXISTS app_check_expired_orders();

-- Create the function with proper error handling
-- Returns JSONB for compatibility with Flutter app expectations
CREATE OR REPLACE FUNCTION app_check_expired_orders()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result RECORD;
  v_response JSONB;
  v_error_message TEXT;
BEGIN
  -- Try to use the scheduled check with advisory locks
  BEGIN
    -- Check if scheduled_check_expired_orders exists and call it
    SELECT * INTO v_result FROM scheduled_check_expired_orders();
    
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
      'processed', COALESCE(v_result.processed, 0),
      'execution_time_ms', COALESCE(v_result.execution_time_ms, 0),
      'lock_acquired', COALESCE(v_result.lock_acquired, false),
      'timestamp', NOW()
    );
    
    RETURN v_response;
    
  EXCEPTION
    WHEN OTHERS THEN
      -- If scheduled_check_expired_orders doesn't exist or fails,
      -- try calling auto_reject_expired_orders directly
      BEGIN
        DECLARE
          v_processed INTEGER := 0;
        BEGIN
          -- Try to call auto_reject_expired_orders directly
          SELECT auto_reject_expired_orders() INTO v_processed;
          
          -- Return success response even if processed count is unknown
          RETURN jsonb_build_object(
            'success', true,
            'processed', v_processed,
            'execution_time_ms', 0,
            'lock_acquired', false,
            'timestamp', NOW(),
            'fallback_mode', true
          );
        EXCEPTION
          WHEN OTHERS THEN
            -- If both functions fail, return an error response (but don't throw)
            v_error_message := SQLERRM;
            RETURN jsonb_build_object(
              'success', false,
              'error', v_error_message,
              'processed', 0,
              'timestamp', NOW()
            );
        END;
      END;
  END;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION app_check_expired_orders() TO authenticated;
GRANT EXECUTE ON FUNCTION app_check_expired_orders() TO anon;

-- Add comment
COMMENT ON FUNCTION app_check_expired_orders IS 
'Checks and processes expired orders. Returns JSONB with success status and processed count. 
This function is called by the Flutter app every 5 seconds.';

