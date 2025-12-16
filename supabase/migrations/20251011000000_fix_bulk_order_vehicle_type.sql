-- Fix post_bulk_order function to properly handle vehicle_type
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
  RAISE NOTICE 'Processing bulk order: %', p_bulk_order_id;
  RAISE NOTICE 'Vehicle type from bulk_record: %', bulk_record.vehicle_type;
  RAISE NOTICE 'Pickup address: %', bulk_record.pickup_address;
  
  -- Validate vehicle type
  IF bulk_record.vehicle_type NOT IN ('motorcycle', 'car', 'truck') THEN
    RAISE EXCEPTION 'Invalid vehicle type in bulk order: %. Must be motorcycle, car, or truck', bulk_record.vehicle_type;
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
      RAISE NOTICE 'Creating order for item %: % -> %', 
        bulk_item.sequence_number, 
        bulk_item.customer_name,
        bulk_item.delivery_address;
      
      -- Create individual order with explicit vehicle_type
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
        bulk_record.merchant_id,
        bulk_item.customer_name,
        bulk_item.customer_phone,
        bulk_record.pickup_address,
        bulk_item.delivery_address,
        bulk_record.pickup_latitude,
        bulk_record.pickup_longitude,
        bulk_item.delivery_latitude,
        bulk_item.delivery_longitude,
        COALESCE(bulk_record.vehicle_type, 'motorcycle'), -- Ensure vehicle_type is never NULL
        bulk_item.total_amount,
        bulk_record.delivery_fee,
        COALESCE(bulk_item.item_notes, '') || CASE WHEN bulk_record.notes IS NOT NULL THEN ' ' || bulk_record.notes ELSE '' END,
        'pending',
        NOW(),
        NOW()
      )
      RETURNING id INTO new_order_id;
      
      RAISE NOTICE 'Created order: %', new_order_id;
      
      -- Update bulk item status
      UPDATE bulk_order_items
      SET status = 'posted',
          created_order_id = new_order_id,
          updated_at = NOW()
      WHERE id = bulk_item.id;
      
      posted := posted + 1;
      
    EXCEPTION WHEN OTHERS THEN
      -- Log detailed error
      RAISE WARNING 'Failed to post bulk order item %: %', bulk_item.id, SQLERRM;
      RAISE WARNING 'Error detail: %', SQLSTATE;
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
  
  RAISE NOTICE 'Bulk order complete: % posted, % failed', posted, failed;
  
  RETURN QUERY SELECT posted, failed;
END;
$$ LANGUAGE plpgsql;

