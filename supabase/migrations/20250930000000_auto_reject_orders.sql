-- Migration: Auto-reject pending orders after 30 seconds if driver doesn't accept
-- This ensures pending orders with assigned drivers don't stay stuck

-- Add driver_assigned_at timestamp column to track when driver was assigned to a pending order
ALTER TABLE orders ADD COLUMN IF NOT EXISTS driver_assigned_at TIMESTAMPTZ;

-- Create a function to auto-reject expired pending orders
CREATE OR REPLACE FUNCTION auto_reject_expired_orders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update pending orders that have had a driver assigned for more than 30 seconds without acceptance
  UPDATE orders
  SET 
    driver_id = NULL,
    driver_assigned_at = NULL,
    updated_at = NOW()
  WHERE 
    status = 'pending'
    AND driver_id IS NOT NULL
    AND driver_assigned_at IS NOT NULL
    AND driver_assigned_at < (NOW() - INTERVAL '30 seconds');
END;
$$;

-- Create a function that tracks when a driver is assigned to a pending order
CREATE OR REPLACE FUNCTION track_driver_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- When a driver is assigned to a pending order, set driver_assigned_at
  IF NEW.status = 'pending' AND NEW.driver_id IS NOT NULL AND OLD.driver_id IS NULL THEN
    NEW.driver_assigned_at = NOW();
  END IF;
  
  -- When driver is removed from pending order, clear driver_assigned_at
  IF NEW.status = 'pending' AND NEW.driver_id IS NULL AND OLD.driver_id IS NOT NULL THEN
    NEW.driver_assigned_at = NULL;
  END IF;
  
  -- When status changes from pending to accepted/rejected, clear driver_assigned_at
  IF NEW.status != 'pending' AND OLD.status = 'pending' THEN
    NEW.driver_assigned_at = NULL;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to automatically track driver assignments on pending orders
DROP TRIGGER IF EXISTS track_driver_assignment_trigger ON orders;
CREATE TRIGGER track_driver_assignment_trigger
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION track_driver_assignment();

-- Create a pg_cron job to run auto-reject every 5 seconds
-- Note: pg_cron extension must be enabled in Supabase
-- This can be done in Supabase dashboard under Database > Extensions

-- If pg_cron is available, create the job:
-- SELECT cron.schedule(
--   'auto-reject-expired-orders',
--   '*/5 * * * * *', -- Every 5 seconds
--   $$SELECT auto_reject_expired_orders()$$
-- );

-- Alternative: Use Supabase Edge Functions with cron trigger
-- Create this in Supabase dashboard:
-- Functions > Create new function > Name: auto-reject-orders
-- Schedule: Every 5 seconds

COMMENT ON FUNCTION auto_reject_expired_orders() IS 
  'Automatically unassigns drivers from pending orders after 30 seconds without acceptance';

COMMENT ON COLUMN orders.driver_assigned_at IS 
  'Timestamp when driver was assigned to a pending order. Used for auto-reject after 30 seconds.';

