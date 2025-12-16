-- Add ready countdown columns to orders table
-- This allows merchants to set when their order will be ready for pickup

-- Add ready_at column (when the order will be ready)
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS ready_at TIMESTAMP WITH TIME ZONE;

-- Add ready_countdown column (minutes until ready)
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS ready_countdown INTEGER DEFAULT 0;

-- Create index for querying ready orders
CREATE INDEX IF NOT EXISTS idx_orders_ready_at ON orders(ready_at) WHERE ready_at IS NOT NULL;

-- Add comments
COMMENT ON COLUMN orders.ready_at IS 'Timestamp when the order will be ready for driver pickup';
COMMENT ON COLUMN orders.ready_countdown IS 'Minutes until order is ready (0 = ready now)';

-- Create function to check if order is ready
CREATE OR REPLACE FUNCTION is_order_ready(order_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  order_ready_at TIMESTAMP WITH TIME ZONE;
BEGIN
  SELECT ready_at INTO order_ready_at
  FROM orders
  WHERE id = order_id;
  
  -- If ready_at is null or in the past, order is ready
  IF order_ready_at IS NULL OR order_ready_at <= NOW() THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION is_order_ready(UUID) IS 'Check if an order is ready for driver pickup based on ready_at timestamp';


