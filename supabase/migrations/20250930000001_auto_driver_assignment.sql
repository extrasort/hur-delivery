-- Migration: Automatic Driver Assignment System
-- Automatically assigns orders to drivers and handles rejection/timeout

-- ============================================================
-- 0. ENABLE POSTGIS EXTENSION
-- Required for distance calculations
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- 1. CREATE REJECTED DRIVERS TABLE
-- Track which drivers have rejected or timed out on each order
-- ============================================================
CREATE TABLE IF NOT EXISTS order_rejected_drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rejected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reason TEXT NOT NULL, -- 'timeout' or 'manual_reject'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(order_id, driver_id)
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_order_rejected_drivers_order ON order_rejected_drivers(order_id);
CREATE INDEX IF NOT EXISTS idx_order_rejected_drivers_driver ON order_rejected_drivers(driver_id);

-- Add spatial index to users table for faster distance queries
-- Note: We use geometry type for the index (geography doesn't support GIST directly)
CREATE INDEX IF NOT EXISTS idx_users_location 
  ON users USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326))
  WHERE role = 'driver' AND latitude IS NOT NULL AND longitude IS NOT NULL;

-- Add index for online drivers
CREATE INDEX IF NOT EXISTS idx_users_online_drivers 
  ON users (is_online, manual_verified, role)
  WHERE role = 'driver';

-- ============================================================
-- 2. FUNCTION: Find Next Available Driver (with PostGIS)
-- Finds nearest online driver who hasn't rejected this order
-- Uses PostGIS for accurate distance calculation
-- ============================================================
CREATE OR REPLACE FUNCTION find_next_available_driver(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_point GEOGRAPHY;
BEGIN
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  -- TIER 1: Try to find driver with NO active orders at all (completely free)
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    AND u.manual_verified = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Driver hasn't rejected this order before
    AND u.id NOT IN (
      SELECT driver_id 
      FROM order_rejected_drivers 
      WHERE order_id = p_order_id
    )
    -- Driver has NO active orders at all (completely free)
    AND u.id NOT IN (
      SELECT driver_id 
      FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('pending', 'accepted', 'on_the_way')
    )
  ORDER BY ST_Distance(
    v_pickup_point,
    ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
  ) ASC
  LIMIT 1;
  
  -- TIER 2: If no completely free driver found, try drivers with only pending orders
  IF v_driver_id IS NULL THEN
    SELECT u.id INTO v_driver_id
    FROM users u
    WHERE u.role = 'driver'
      AND u.is_online = true
      AND u.manual_verified = true
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      -- Driver hasn't rejected this order before
      AND u.id NOT IN (
        SELECT driver_id 
        FROM order_rejected_drivers 
        WHERE order_id = p_order_id
      )
      -- Driver doesn't have accepted/on_the_way orders (but may have pending)
      AND u.id NOT IN (
        SELECT driver_id 
        FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('accepted', 'on_the_way')
      )
    ORDER BY ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) ASC
    LIMIT 1;
  END IF;
  
  RETURN v_driver_id;
END;
$$;

-- ============================================================
-- 2b. FUNCTION: Get Ranked Available Drivers
-- Returns list of available drivers ranked by distance
-- Useful for debugging and manual assignment
-- ============================================================
CREATE OR REPLACE FUNCTION get_ranked_available_drivers(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  distance_meters DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_online BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pickup_point GEOGRAPHY;
BEGIN
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  RETURN QUERY
  SELECT 
    u.id as driver_id,
    u.name as driver_name,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) as distance_meters,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) / 1000.0 as distance_km,
    u.latitude,
    u.longitude,
    u.is_online
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    AND u.manual_verified = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Driver hasn't rejected this order before
    AND u.id NOT IN (
      SELECT driver_id 
      FROM order_rejected_drivers 
      WHERE order_id = p_order_id
    )
    -- Driver doesn't have an active order
    AND u.id NOT IN (
      SELECT driver_id 
      FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('accepted', 'on_the_way')
    )
  ORDER BY distance_meters ASC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- 3. FUNCTION: Auto-Assign Order to Driver
-- Automatically assigns order to next available driver
-- ============================================================
CREATE OR REPLACE FUNCTION auto_assign_order(p_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_lat DOUBLE PRECISION;
  v_pickup_lng DOUBLE PRECISION;
  v_order_status TEXT;
BEGIN
  -- Get order details
  SELECT status, pickup_latitude, pickup_longitude
  INTO v_order_status, v_pickup_lat, v_pickup_lng
  FROM orders
  WHERE id = p_order_id;
  
  -- Only assign if order is pending and has no driver
  IF v_order_status != 'pending' THEN
    RETURN FALSE;
  END IF;
  
  -- Find next available driver
  v_driver_id := find_next_available_driver(p_order_id, v_pickup_lat, v_pickup_lng);
  
  IF v_driver_id IS NULL THEN
    -- No available drivers
    RAISE NOTICE 'No available drivers found for order %', p_order_id;
    RETURN FALSE;
  END IF;
  
  -- Assign order to driver (this triggers the driver_assigned_at timestamp)
  UPDATE orders
  SET 
    driver_id = v_driver_id,
    updated_at = NOW()
  WHERE id = p_order_id
    AND status = 'pending'
    AND driver_id IS NULL; -- Ensure it hasn't been assigned already
  
  IF FOUND THEN
    RAISE NOTICE 'Assigned order % to driver %', p_order_id, v_driver_id;
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$;

-- ============================================================
-- 4. ENHANCED: Auto-Reject Function with Re-assignment
-- When driver times out, add to rejected list and find next driver
-- ============================================================
CREATE OR REPLACE FUNCTION auto_reject_expired_orders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_order RECORD;
BEGIN
  -- Loop through all expired orders
  FOR expired_order IN
    SELECT id, driver_id
    FROM orders
    WHERE status = 'pending'
      AND driver_id IS NOT NULL
      AND driver_assigned_at IS NOT NULL
      AND driver_assigned_at < (NOW() - INTERVAL '30 seconds')
  LOOP
    -- Add driver to rejected list for this order
    INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
    VALUES (expired_order.id, expired_order.driver_id, 'timeout')
    ON CONFLICT (order_id, driver_id) DO NOTHING;
    
    -- Remove driver from order
    UPDATE orders
    SET 
      driver_id = NULL,
      driver_assigned_at = NULL,
      updated_at = NOW()
    WHERE id = expired_order.id;
    
    -- Try to assign to next available driver
    PERFORM auto_assign_order(expired_order.id);
    
    RAISE NOTICE 'Driver % timed out on order %. Reassigning...', expired_order.driver_id, expired_order.id;
  END LOOP;
END;
$$;

-- ============================================================
-- 5. TRIGGER: Auto-Assign on Order Creation
-- Automatically assigns driver when order is created
-- ============================================================
CREATE OR REPLACE FUNCTION trigger_auto_assign_on_create()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only auto-assign if order is pending and has no driver
  IF NEW.status = 'pending' AND NEW.driver_id IS NULL THEN
    -- Use pg_notify to trigger async assignment (non-blocking)
    PERFORM pg_notify('new_order', NEW.id::text);
    
    -- Or directly assign (blocking, but simpler)
    PERFORM auto_assign_order(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger on order insert
DROP TRIGGER IF EXISTS auto_assign_new_orders ON orders;
CREATE TRIGGER auto_assign_new_orders
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_auto_assign_on_create();

-- ============================================================
-- 6. FUNCTION: Manual Driver Rejection
-- When driver clicks "reject", add to rejected list and reassign
-- ============================================================
CREATE OR REPLACE FUNCTION reject_order_and_reassign(
  p_order_id UUID,
  p_driver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Add driver to rejected list
  INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
  VALUES (p_order_id, p_driver_id, 'manual_reject')
  ON CONFLICT (order_id, driver_id) DO NOTHING;
  
  -- Update order status
  UPDATE orders
  SET 
    driver_id = NULL,
    driver_assigned_at = NULL,
    status = 'pending',
    updated_at = NOW()
  WHERE id = p_order_id
    AND driver_id = p_driver_id;
  
  -- Try to assign to next available driver
  PERFORM auto_assign_order(p_order_id);
  
  RETURN TRUE;
END;
$$;

-- ============================================================
-- 7. COMMENTS & DOCUMENTATION
-- ============================================================
COMMENT ON TABLE order_rejected_drivers IS 
  'Tracks drivers who have rejected or timed out on each order to prevent reassignment';

COMMENT ON FUNCTION find_next_available_driver IS 
  'Finds the nearest online driver who has not rejected the order and has no active orders';

COMMENT ON FUNCTION auto_assign_order IS 
  'Automatically assigns an order to the next available driver';

COMMENT ON FUNCTION auto_reject_expired_orders IS 
  'Auto-rejects expired orders and reassigns them to next available driver';

COMMENT ON FUNCTION reject_order_and_reassign IS 
  'Handles manual driver rejection and automatically reassigns to next driver';

