-- Migration: Add Vehicle Type Compatibility to Driver Assignment
-- Ensures orders are only assigned to drivers with compatible vehicle types

-- ============================================================
-- 1. Add vehicle_type column to users table if it doesn't exist
-- ============================================================
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'vehicle_type'
  ) THEN
    ALTER TABLE users ADD COLUMN vehicle_type TEXT;
    
    -- Add constraint to match order vehicle types
    ALTER TABLE users 
      ADD CONSTRAINT users_vehicle_type_check 
      CHECK (vehicle_type IN ('motorcycle', 'car', 'truck', 'motorbike') OR vehicle_type IS NULL);
    
    -- Add index for faster vehicle type lookups
    CREATE INDEX IF NOT EXISTS idx_users_vehicle_type ON users(vehicle_type) WHERE role = 'driver';
    
    RAISE NOTICE 'Added vehicle_type column to users table';
  END IF;
END $$;

-- ============================================================
-- 2. CREATE: Find Next Available Driver with Vehicle Type (4 params)
-- This is the new version with vehicle type support
-- ============================================================
CREATE OR REPLACE FUNCTION find_next_available_driver(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION,
  p_vehicle_type TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_point GEOGRAPHY;
  v_required_vehicle TEXT;
BEGIN
  -- Normalize vehicle type (motorbike -> motorcycle)
  v_required_vehicle := CASE 
    WHEN p_vehicle_type = 'motorbike' THEN 'motorcycle'
    ELSE p_vehicle_type
  END;
  
  RAISE NOTICE 'Finding driver for order % with vehicle type: %', p_order_id, v_required_vehicle;
  
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  -- TIER 1: Try to find driver with NO active orders at all (completely free)
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Vehicle type compatibility check
    -- If 'any' is requested, accept any vehicle type
    AND (
      v_required_vehicle IS NULL 
      OR v_required_vehicle = 'any'
      OR u.vehicle_type IS NULL 
      OR u.vehicle_type = v_required_vehicle
      OR u.vehicle_type = 'motorbike' AND v_required_vehicle = 'motorcycle'
      OR u.vehicle_type = 'motorcycle' AND v_required_vehicle = 'motorbike'
    )
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
      -- Vehicle type compatibility check
      AND (
        v_required_vehicle IS NULL 
        OR u.vehicle_type IS NULL 
        OR u.vehicle_type = v_required_vehicle
        OR u.vehicle_type = 'motorbike' AND v_required_vehicle = 'motorcycle'
        OR u.vehicle_type = 'motorcycle' AND v_required_vehicle = 'motorbike'
      )
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
  
  IF v_driver_id IS NOT NULL THEN
    RAISE NOTICE 'Found driver % for order % (vehicle type: %)', v_driver_id, p_order_id, v_required_vehicle;
  ELSE
    RAISE NOTICE 'No compatible driver found for order % (vehicle type: %)', p_order_id, v_required_vehicle;
  END IF;
  
  RETURN v_driver_id;
END;
$$;

-- ============================================================
-- 3. CREATE: Backward Compatible Wrapper (3 params)
-- Maintains compatibility with existing code
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
BEGIN
  -- Call the new 4-parameter version with NULL vehicle type
  RETURN find_next_available_driver(p_order_id, p_pickup_lat, p_pickup_lng, NULL);
END;
$$;

-- ============================================================
-- 4. CREATE: Get Ranked Available Drivers with Vehicle Type (5 params)
-- ============================================================
CREATE OR REPLACE FUNCTION get_ranked_available_drivers(
  p_order_id UUID,
  p_pickup_lat DOUBLE PRECISION,
  p_pickup_lng DOUBLE PRECISION,
  p_limit INTEGER DEFAULT 10,
  p_vehicle_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  vehicle_type TEXT,
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
  v_required_vehicle TEXT;
BEGIN
  -- Normalize vehicle type
  v_required_vehicle := CASE 
    WHEN p_vehicle_type = 'motorbike' THEN 'motorcycle'
    ELSE p_vehicle_type
  END;
  
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  RETURN QUERY
  SELECT 
    u.id as driver_id,
    u.name as driver_name,
    u.vehicle_type,
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
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Vehicle type compatibility check
    -- If 'any' is requested, accept any vehicle type
    AND (
      v_required_vehicle IS NULL 
      OR v_required_vehicle = 'any'
      OR u.vehicle_type IS NULL 
      OR u.vehicle_type = v_required_vehicle
      OR u.vehicle_type = 'motorbike' AND v_required_vehicle = 'motorcycle'
      OR u.vehicle_type = 'motorcycle' AND v_required_vehicle = 'motorbike'
    )
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
-- 5. CREATE: Backward Compatible Wrapper for get_ranked_available_drivers (4 params)
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
  vehicle_type TEXT,
  distance_meters DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_online BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Call the new 5-parameter version with NULL vehicle type
  RETURN QUERY SELECT * FROM get_ranked_available_drivers(p_order_id, p_pickup_lat, p_pickup_lng, p_limit, NULL);
END;
$$;

-- ============================================================
-- 6. UPDATE: Auto-Assign Order with Vehicle Type
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
  v_vehicle_type TEXT;
BEGIN
  -- Get order details including vehicle type
  SELECT status, pickup_latitude, pickup_longitude, vehicle_type
  INTO v_order_status, v_pickup_lat, v_pickup_lng, v_vehicle_type
  FROM orders
  WHERE id = p_order_id;
  
  -- Only assign if order is pending and has no driver
  IF v_order_status != 'pending' THEN
    RAISE NOTICE 'Order % is not pending (status: %)', p_order_id, v_order_status;
    RETURN FALSE;
  END IF;
  
  -- Find next available driver with compatible vehicle
  v_driver_id := find_next_available_driver(p_order_id, v_pickup_lat, v_pickup_lng, v_vehicle_type);
  
  IF v_driver_id IS NULL THEN
    -- No available drivers with compatible vehicle
    RAISE NOTICE 'No available drivers found for order % (vehicle type: %)', p_order_id, v_vehicle_type;
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
    RAISE NOTICE 'Assigned order % (vehicle: %) to driver %', p_order_id, v_vehicle_type, v_driver_id;
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$;

-- ============================================================
-- 7. UPDATE COMMENTS
-- ============================================================
COMMENT ON FUNCTION find_next_available_driver(UUID, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) IS 
  'Finds the nearest online driver who has not rejected the order, has no active orders, and has a compatible vehicle type. Supports vehicle type filtering.';

COMMENT ON FUNCTION find_next_available_driver(UUID, DOUBLE PRECISION, DOUBLE PRECISION) IS 
  'Backward compatible wrapper that finds the nearest online driver without vehicle type filtering.';

COMMENT ON FUNCTION get_ranked_available_drivers(UUID, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, TEXT) IS 
  'Returns list of available drivers with compatible vehicle types ranked by distance. Supports vehicle type filtering.';

COMMENT ON FUNCTION get_ranked_available_drivers(UUID, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER) IS 
  'Backward compatible wrapper that returns available drivers without vehicle type filtering.';

COMMENT ON FUNCTION auto_assign_order(UUID) IS 
  'Automatically assigns an order to the next available driver with compatible vehicle type based on the order''s vehicle_type field.';

