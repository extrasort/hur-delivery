-- =====================================================================================
-- ADD VEHICLE TYPE TO ORDERS TABLE
-- =====================================================================================
-- Adds vehicle_type column to orders table to track required vehicle type for delivery
-- Values: 'motorbike' (default), 'car', 'truck'
-- =====================================================================================

-- Add vehicle_type column to orders table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS vehicle_type TEXT NOT NULL DEFAULT 'motorbike' 
CHECK (vehicle_type IN ('motorbike', 'car', 'truck'));

-- Add index for filtering orders by vehicle type
CREATE INDEX IF NOT EXISTS idx_orders_vehicle_type ON orders(vehicle_type);

-- Add comment for documentation
COMMENT ON COLUMN orders.vehicle_type IS 'Required vehicle type for this order: motorbike (default), car, or truck';

-- Update existing orders to have default vehicle type
UPDATE orders 
SET vehicle_type = 'motorbike' 
WHERE vehicle_type IS NULL;

