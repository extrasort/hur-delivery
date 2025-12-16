-- Migration: Set default vehicle types for all drivers
-- Sets all existing drivers to have 'motorcycle' as their vehicle type

-- Update all drivers to have motorcycle as default vehicle type
UPDATE users 
SET vehicle_type = 'motorcycle', 
    updated_at = NOW()
WHERE role = 'driver' 
  AND vehicle_type IS NULL;

-- Log the changes
DO $$
DECLARE
  updated_count INTEGER;
BEGIN
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE 'Updated % drivers to have motorcycle as vehicle type', updated_count;
END $$;

-- Optionally, you can also set a default for future driver registrations
-- by adding a default value to the column
ALTER TABLE users 
  ALTER COLUMN vehicle_type SET DEFAULT 'motorcycle';

COMMENT ON COLUMN users.vehicle_type IS 
  'Type of vehicle the driver uses: motorcycle, car, or truck. Defaults to motorcycle for new drivers.';

