-- Enable pg_cron extension for scheduled jobs
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Function to process scheduled orders that are due
CREATE OR REPLACE FUNCTION process_scheduled_orders()
RETURNS TABLE(processed_count INTEGER, failed_count INTEGER) AS $$
DECLARE
  scheduled_item RECORD;
  new_order_id UUID;
  processed INTEGER := 0;
  failed INTEGER := 0;
BEGIN
  RAISE NOTICE '====================================';
  RAISE NOTICE 'PROCESSING SCHEDULED ORDERS';
  RAISE NOTICE 'Current Time: %', NOW();
  RAISE NOTICE '====================================';
  
  -- Find all scheduled orders that are due (scheduled_date + scheduled_time <= NOW)
  FOR scheduled_item IN
    SELECT * FROM scheduled_orders
    WHERE status = 'scheduled'
    AND (scheduled_date + scheduled_time) <= NOW()
    ORDER BY (scheduled_date + scheduled_time) ASC
  LOOP
    BEGIN
      RAISE NOTICE '------------------------------------';
      RAISE NOTICE 'Processing scheduled order: %', scheduled_item.id;
      RAISE NOTICE '  Merchant ID: %', scheduled_item.merchant_id;
      RAISE NOTICE '  Customer: %', scheduled_item.customer_name;
      RAISE NOTICE '  Phone: %', scheduled_item.customer_phone;
      RAISE NOTICE '  Scheduled for: % %', scheduled_item.scheduled_date, scheduled_item.scheduled_time;
      RAISE NOTICE '  Vehicle Type: "%"', scheduled_item.vehicle_type;
      
      -- Validate vehicle type
      IF scheduled_item.vehicle_type IS NULL THEN
        RAISE EXCEPTION 'Vehicle type cannot be NULL';
      END IF;
      
      -- Normalize motorbike to motorcycle
      IF scheduled_item.vehicle_type = 'motorbike' THEN
        scheduled_item.vehicle_type := 'motorcycle';
        RAISE NOTICE '  Normalized vehicle type from motorbike to motorcycle';
      END IF;
      
      IF scheduled_item.vehicle_type NOT IN ('motorcycle', 'car', 'truck') THEN
        RAISE EXCEPTION 'Invalid vehicle type: "%". Must be one of: motorcycle, car, truck', scheduled_item.vehicle_type;
      END IF;
      
      -- Create the order
      INSERT INTO orders (
        merchant_id,
        customer_name,
        customer_phone,
        pickup_address,
        delivery_address,
        pickup_latitude,
        pickup_longitude,
        delivery_latitude,
        delivery_longitude,
        vehicle_type,
        total_amount,
        delivery_fee,
        notes,
        status,
        created_at,
        updated_at
      ) VALUES (
        scheduled_item.merchant_id,
        scheduled_item.customer_name,
        scheduled_item.customer_phone,
        scheduled_item.pickup_address,
        scheduled_item.delivery_address,
        scheduled_item.pickup_latitude,
        scheduled_item.pickup_longitude,
        scheduled_item.delivery_latitude,
        scheduled_item.delivery_longitude,
        scheduled_item.vehicle_type,
        scheduled_item.total_amount,
        scheduled_item.delivery_fee,
        scheduled_item.notes,
        'pending',
        NOW(),
        NOW()
      )
      RETURNING id INTO new_order_id;
      
      RAISE NOTICE '  ✓ Created order: %', new_order_id;
      
      -- Update scheduled order status
      UPDATE scheduled_orders
      SET status = 'posted',
          created_order_id = new_order_id,
          updated_at = NOW()
      WHERE id = scheduled_item.id;
      
      processed := processed + 1;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '  ✗ FAILED to create order for scheduled item %', scheduled_item.id;
      RAISE WARNING '  Error: %', SQLERRM;
      RAISE WARNING '  SQL State: %', SQLSTATE;
      
      -- Update scheduled order to failed status
      UPDATE scheduled_orders
      SET status = 'failed',
          updated_at = NOW()
      WHERE id = scheduled_item.id;
      
      failed := failed + 1;
    END;
  END LOOP;
  
  IF processed > 0 OR failed > 0 THEN
    RAISE NOTICE '====================================';
    RAISE NOTICE 'SCHEDULED ORDERS PROCESSED';
    RAISE NOTICE 'Posted: % | Failed: %', processed, failed;
    RAISE NOTICE '====================================';
  END IF;
  
  RETURN QUERY SELECT processed, failed;
END;
$$ LANGUAGE plpgsql;

-- Add comment to the function
COMMENT ON FUNCTION process_scheduled_orders() IS 'Processes scheduled orders that are due and creates them as regular orders';

-- Add created_order_id column to scheduled_orders if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'scheduled_orders' AND column_name = 'created_order_id'
  ) THEN
    ALTER TABLE scheduled_orders ADD COLUMN created_order_id UUID REFERENCES orders(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_scheduled_orders_created_order_id ON scheduled_orders(created_order_id);
  END IF;
END $$;

-- Schedule the function to run every minute using pg_cron
-- Note: pg_cron uses UTC timezone by default
SELECT cron.schedule(
  'process-scheduled-orders',  -- job name
  '* * * * *',                 -- cron expression: every minute
  $$SELECT process_scheduled_orders();$$
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- Add index for better performance on scheduled_date and scheduled_time lookups
CREATE INDEX IF NOT EXISTS idx_scheduled_orders_status_scheduled_datetime 
ON scheduled_orders(status, scheduled_date, scheduled_time) 
WHERE status = 'scheduled';

COMMENT ON INDEX idx_scheduled_orders_status_scheduled_datetime IS 'Optimizes scheduled order processing by indexing status, scheduled_date and scheduled_time';

