-- First, check and recreate the vehicle_type constraint to match our app
-- Drop existing constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_vehicle_type_check;

-- Add correct constraint that matches the app's usage
ALTER TABLE orders 
  ADD CONSTRAINT orders_vehicle_type_check 
  CHECK (vehicle_type IN ('motorcycle', 'car', 'truck', 'motorbike'));

-- Update any existing 'motorbike' values to 'motorcycle' for consistency
UPDATE orders SET vehicle_type = 'motorcycle' WHERE vehicle_type = 'motorbike';

-- Update bulk_orders constraint
ALTER TABLE bulk_orders DROP CONSTRAINT IF EXISTS bulk_orders_vehicle_type_check;
ALTER TABLE bulk_orders 
  ADD CONSTRAINT bulk_orders_vehicle_type_check 
  CHECK (vehicle_type IN ('motorcycle', 'car', 'truck', 'motorbike'));

-- Update scheduled_orders constraint  
ALTER TABLE scheduled_orders DROP CONSTRAINT IF EXISTS scheduled_orders_vehicle_type_check;
ALTER TABLE scheduled_orders 
  ADD CONSTRAINT scheduled_orders_vehicle_type_check 
  CHECK (vehicle_type IN ('motorcycle', 'car', 'truck', 'motorbike'));

-- Final improved post_bulk_order function with detailed logging
CREATE OR REPLACE FUNCTION post_bulk_order(p_bulk_order_id UUID)
RETURNS TABLE(posted_count INTEGER, failed_count INTEGER) AS $$
DECLARE
  bulk_item RECORD;
  bulk_record RECORD;
  new_order_id UUID;
  posted INTEGER := 0;
  failed INTEGER := 0;
BEGIN
  -- Get bulk order details
  SELECT * INTO bulk_record FROM bulk_orders WHERE id = p_bulk_order_id;
  
  IF bulk_record IS NULL THEN
    RAISE EXCEPTION 'Bulk order not found: %', p_bulk_order_id;
  END IF;
  
  -- Debug logging
  RAISE NOTICE '====================================';
  RAISE NOTICE 'STARTING BULK ORDER POSTING';
  RAISE NOTICE '====================================';
  RAISE NOTICE 'Bulk Order ID: %', p_bulk_order_id;
  RAISE NOTICE 'Merchant ID: %', bulk_record.merchant_id;
  RAISE NOTICE 'Vehicle Type: "%"', bulk_record.vehicle_type;
  RAISE NOTICE 'Pickup Address: %', bulk_record.pickup_address;
  RAISE NOTICE 'Delivery Fee: %', bulk_record.delivery_fee;
  RAISE NOTICE 'Total Orders: %', bulk_record.total_orders;
  
  -- Validate and normalize vehicle type
  IF bulk_record.vehicle_type IS NULL THEN
    RAISE EXCEPTION 'Vehicle type cannot be NULL';
  END IF;
  
  -- Normalize motorbike to motorcycle
  IF bulk_record.vehicle_type = 'motorbike' THEN
    bulk_record.vehicle_type := 'motorcycle';
    RAISE NOTICE 'Normalized vehicle type from motorbike to motorcycle';
  END IF;
  
  IF bulk_record.vehicle_type NOT IN ('motorcycle', 'car', 'truck') THEN
    RAISE EXCEPTION 'Invalid vehicle type: "%". Must be one of: motorcycle, car, truck', bulk_record.vehicle_type;
  END IF;
  
  -- Update status to posting
  UPDATE bulk_orders SET status = 'posting', updated_at = NOW()
  WHERE id = p_bulk_order_id;
  
  -- Post each bulk order item as a separate order
  FOR bulk_item IN
    SELECT * FROM bulk_order_items
    WHERE bulk_order_id = p_bulk_order_id
    AND status = 'pending'
    ORDER BY sequence_number ASC
  LOOP
    BEGIN
      RAISE NOTICE '------------------------------------';
      RAISE NOTICE 'Item %: Creating order', bulk_item.sequence_number;
      RAISE NOTICE '  Customer: %', bulk_item.customer_name;
      RAISE NOTICE '  Phone: %', bulk_item.customer_phone;
      RAISE NOTICE '  Delivery: %', bulk_item.delivery_address;
      RAISE NOTICE '  Amount: %', bulk_item.total_amount;
      RAISE NOTICE '  Using vehicle type: "%"', bulk_record.vehicle_type;
      
      -- Create individual order
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
        bulk_order_id,
        created_at,
        updated_at
      ) VALUES (
        bulk_record.merchant_id,
        bulk_item.customer_name,
        bulk_item.customer_phone,
        bulk_record.pickup_address,
        bulk_item.delivery_address,
        bulk_record.pickup_latitude,
        bulk_record.pickup_longitude,
        bulk_item.delivery_latitude,
        bulk_item.delivery_longitude,
        bulk_record.vehicle_type, -- Already validated
        bulk_item.total_amount,
        bulk_record.delivery_fee,
        COALESCE(bulk_item.item_notes, '') || CASE WHEN bulk_record.notes IS NOT NULL AND bulk_record.notes != '' THEN ' | ' || bulk_record.notes ELSE '' END,
        'pending',
        p_bulk_order_id,
        NOW(),
        NOW()
      )
      RETURNING id INTO new_order_id;
      
      RAISE NOTICE '  ✓ Created order: %', new_order_id;
      
      -- Update bulk item status
      UPDATE bulk_order_items
      SET status = 'posted',
          created_order_id = new_order_id,
          updated_at = NOW()
      WHERE id = bulk_item.id;
      
      posted := posted + 1;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '  ✗ FAILED to create order for item %', bulk_item.id;
      RAISE WARNING '  Error: %', SQLERRM;
      RAISE WARNING '  SQL State: %', SQLSTATE;
      RAISE WARNING '  Vehicle type was: "%"', bulk_record.vehicle_type;
      failed := failed + 1;
    END;
  END LOOP;
  
  -- Update bulk order
  UPDATE bulk_orders
  SET posted_orders = posted,
      status = CASE
        WHEN posted = total_orders THEN 'completed'
        WHEN posted > 0 THEN 'posting'
        ELSE 'draft'
      END,
      updated_at = NOW()
  WHERE id = p_bulk_order_id;
  
  RAISE NOTICE '====================================';
  RAISE NOTICE 'BULK ORDER COMPLETE';
  RAISE NOTICE 'Posted: % | Failed: %', posted, failed;
  RAISE NOTICE '====================================';
  
  RETURN QUERY SELECT posted, failed;
END;
$$ LANGUAGE plpgsql;

