-- Migration: Add function to check vehicle type availability
-- Prevents order creation if no drivers are online with the requested vehicle type

-- ============================================================
-- 1. FUNCTION: Check if vehicle type is available
-- Returns true if there are online drivers with the specified vehicle type
-- ============================================================
CREATE OR REPLACE FUNCTION is_vehicle_type_available(
  p_vehicle_type TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_count INTEGER;
  v_normalized_vehicle TEXT;
BEGIN
  -- Handle 'any' vehicle type - check if ANY drivers are online
  IF p_vehicle_type = 'any' THEN
    SELECT COUNT(*) INTO v_driver_count
    FROM users
    WHERE role = 'driver'
      AND is_online = true
      AND manual_verified = true;
    
    RAISE NOTICE 'Vehicle type "any" availability check: % drivers online', v_driver_count;
    RETURN v_driver_count > 0;
  END IF;
  
  -- Normalize vehicle type
  v_normalized_vehicle := CASE 
    WHEN p_vehicle_type = 'motorbike' THEN 'motorcycle'
    ELSE p_vehicle_type
  END;
  
  -- Count online drivers with this vehicle type
  SELECT COUNT(*) INTO v_driver_count
  FROM users
  WHERE role = 'driver'
    AND is_online = true
    AND (
      vehicle_type = v_normalized_vehicle
      OR (vehicle_type = 'motorbike' AND v_normalized_vehicle = 'motorcycle')
      OR (vehicle_type = 'motorcycle' AND v_normalized_vehicle = 'motorbike')
    );
  
  RAISE NOTICE 'Vehicle type % availability check: % drivers online', v_normalized_vehicle, v_driver_count;
  
  RETURN v_driver_count > 0;
END;
$$;

-- ============================================================
-- 2. FUNCTION: Get available vehicle types
-- Returns list of vehicle types that have online drivers
-- ============================================================
CREATE OR REPLACE FUNCTION get_available_vehicle_types()
RETURNS TABLE (
  vehicle_type TEXT,
  driver_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(
      CASE 
        WHEN u.vehicle_type = 'motorbike' THEN 'motorcycle'
        ELSE u.vehicle_type
      END,
      'motorcycle'
    ) as vehicle_type,
    COUNT(*)::INTEGER as driver_count
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = true
  GROUP BY COALESCE(
    CASE 
      WHEN u.vehicle_type = 'motorbike' THEN 'motorcycle'
      ELSE u.vehicle_type
    END,
    'motorcycle'
  )
  ORDER BY vehicle_type;
END;
$$;

-- ============================================================
-- 3. FUNCTION: Validate order creation
-- Checks if order can be created with the specified vehicle type
-- ============================================================
CREATE OR REPLACE FUNCTION validate_order_vehicle_type(
  p_vehicle_type TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_available BOOLEAN;
  v_driver_count INTEGER;
  v_normalized_vehicle TEXT;
BEGIN
  -- Handle 'any' vehicle type - check if ANY drivers are online
  IF p_vehicle_type = 'any' THEN
    SELECT COUNT(*) INTO v_driver_count
    FROM users
    WHERE role = 'driver'
      AND is_online = true;
    
    v_is_available := v_driver_count > 0;
    
    RETURN json_build_object(
      'available', v_is_available,
      'vehicle_type', 'any',
      'driver_count', v_driver_count,
      'message', CASE 
        WHEN v_is_available THEN format('%s drivers available (any vehicle type)', v_driver_count)
        ELSE 'No drivers online. Please try again later.'
      END
    );
  END IF;
  
  -- Normalize vehicle type
  v_normalized_vehicle := CASE 
    WHEN p_vehicle_type = 'motorbike' THEN 'motorcycle'
    ELSE p_vehicle_type
  END;
  
  -- Check availability
  SELECT COUNT(*) INTO v_driver_count
  FROM users
  WHERE role = 'driver'
    AND is_online = true
    AND (
      vehicle_type = v_normalized_vehicle
      OR (vehicle_type = 'motorbike' AND v_normalized_vehicle = 'motorcycle')
      OR (vehicle_type = 'motorcycle' AND v_normalized_vehicle = 'motorbike')
    );
  
  v_is_available := v_driver_count > 0;
  
  -- Return JSON response
  RETURN json_build_object(
    'available', v_is_available,
    'vehicle_type', v_normalized_vehicle,
    'driver_count', v_driver_count,
    'message', CASE 
      WHEN v_is_available THEN format('%s drivers with %s available', v_driver_count, v_normalized_vehicle)
      ELSE format('No %s drivers online. Please choose another vehicle type.', v_normalized_vehicle)
    END
  );
END;
$$;

-- ============================================================
-- 4. Add comments
-- ============================================================
COMMENT ON FUNCTION is_vehicle_type_available(TEXT) IS 
  'Checks if there are online drivers available with the specified vehicle type';

COMMENT ON FUNCTION get_available_vehicle_types() IS 
  'Returns list of vehicle types that currently have online drivers available';

COMMENT ON FUNCTION validate_order_vehicle_type(TEXT) IS 
  'Validates if an order can be created with the specified vehicle type and returns detailed information';

