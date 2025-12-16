-- =====================================================================================
-- ADD "ANY" VEHICLE TYPE SUPPORT
-- =====================================================================================
-- Allows orders to accept any vehicle type for driver assignment
-- When vehicle_type = 'any', any driver with any vehicle can accept the order
-- =====================================================================================

-- STEP 1: Update existing orders with invalid or NULL vehicle types
UPDATE orders 
SET vehicle_type = 'motorbike' 
WHERE vehicle_type IS NULL OR vehicle_type NOT IN ('motorbike', 'car', 'truck', 'any');

-- STEP 2: Handle 'motorcycle' variant (some orders might use this)
UPDATE orders 
SET vehicle_type = 'motorbike' 
WHERE vehicle_type = 'motorcycle';

-- STEP 3: Drop old constraint if it exists
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_vehicle_type_check;

-- STEP 4: Add new constraint with 'any' option
ALTER TABLE orders ADD CONSTRAINT orders_vehicle_type_check 
CHECK (vehicle_type IN ('motorbike', 'car', 'truck', 'any'));

-- Update the driver assignment function to handle 'any' vehicle type
CREATE OR REPLACE FUNCTION get_nearby_drivers_for_order(
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
  is_online BOOLEAN,
  total_deliveries INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id as driver_id,
    u.name as driver_name,
    u.vehicle_type,
    ST_Distance(
      ST_MakePoint(dl.longitude, dl.latitude)::geography,
      ST_MakePoint(p_pickup_lng, p_pickup_lat)::geography
    ) as distance_meters,
    ST_Distance(
      ST_MakePoint(dl.longitude, dl.latitude)::geography,
      ST_MakePoint(p_pickup_lng, p_pickup_lat)::geography
    ) / 1000.0 as distance_km,
    dl.latitude,
    dl.longitude,
    u.is_online,
    (SELECT COUNT(*) FROM orders WHERE driver_id = u.id AND status = 'delivered')::INTEGER as total_deliveries
  FROM users u
  INNER JOIN LATERAL (
    SELECT latitude, longitude
    FROM driver_locations
    WHERE driver_id = u.id
    ORDER BY created_at DESC
    LIMIT 1
  ) dl ON true
  WHERE u.role = 'driver'
    AND u.is_online = true
    AND u.verification_status = 'approved'
    AND u.manual_verified = true
    -- Vehicle type matching: if p_vehicle_type is 'any', accept all drivers
    -- If specific type, only match that type
    AND (p_vehicle_type IS NULL OR p_vehicle_type = 'any' OR u.vehicle_type = p_vehicle_type)
    -- Exclude drivers who already rejected this order
    AND NOT EXISTS (
      SELECT 1 FROM order_assignments oa
      WHERE oa.driver_id = u.id
        AND oa.order_id = p_order_id
        AND oa.status = 'rejected'
    )
    -- Exclude drivers who are currently assigned to active orders
    AND NOT EXISTS (
      SELECT 1 FROM orders o
      WHERE o.driver_id = u.id
        AND o.status IN ('assigned', 'accepted', 'picked_up', 'on_the_way')
    )
  ORDER BY distance_meters ASC
  LIMIT p_limit;
END;
$$;

-- Comment
COMMENT ON FUNCTION get_nearby_drivers_for_order IS 'Get nearby available drivers for an order. When vehicle_type is "any", returns drivers with any vehicle type';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_nearby_drivers_for_order TO authenticated;

-- =====================================================================================
-- DONE! "Any" vehicle type is now supported
-- =====================================================================================

-- Test query:
-- SELECT * FROM get_nearby_drivers_for_order(
--   'order_id_here',
--   33.3152,  -- Baghdad latitude
--   44.3661,  -- Baghdad longitude
--   10,
--   'any'     -- Accept any vehicle type
-- );

