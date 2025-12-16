-- Create scheduled_orders table for future order scheduling
CREATE TABLE IF NOT EXISTS scheduled_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Relationships
  merchant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  
  -- Customer Information
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  
  -- Pickup Location
  pickup_address TEXT NOT NULL,
  pickup_latitude DECIMAL(10,8) NOT NULL,
  pickup_longitude DECIMAL(11,8) NOT NULL,
  
  -- Delivery Location
  delivery_address TEXT NOT NULL,
  delivery_latitude DECIMAL(10,8) NOT NULL,
  delivery_longitude DECIMAL(11,8) NOT NULL,
  
  -- Order Details
  total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  delivery_fee DECIMAL(12,2) NOT NULL DEFAULT 0,
  grand_total DECIMAL(12,2) GENERATED ALWAYS AS (total_amount + delivery_fee) STORED,
  notes TEXT,
  vehicle_type TEXT NOT NULL DEFAULT 'motorcycle' CHECK (vehicle_type IN ('motorcycle', 'car', 'truck', 'motorbike')),
  
  -- Scheduling
  scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'posted', 'failed', 'cancelled')),
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_scheduled_orders_merchant_id ON scheduled_orders(merchant_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_orders_status ON scheduled_orders(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_orders_scheduled_at ON scheduled_orders(scheduled_at) WHERE status = 'scheduled';
CREATE INDEX IF NOT EXISTS idx_scheduled_orders_created_order_id ON scheduled_orders(created_order_id);

-- RLS Policies
ALTER TABLE scheduled_orders ENABLE ROW LEVEL SECURITY;

-- Merchants can create and view their own scheduled orders
DO $$ BEGIN
  CREATE POLICY "Merchants can insert their own scheduled orders"
    ON scheduled_orders FOR INSERT
    TO authenticated
    WITH CHECK (
      auth.uid() = merchant_id AND
      EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'merchant')
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Merchants can view their own scheduled orders"
    ON scheduled_orders FOR SELECT
    TO authenticated
    USING (
      auth.uid() = merchant_id AND
      EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'merchant')
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Merchants can update their own scheduled orders"
    ON scheduled_orders FOR UPDATE
    TO authenticated
    USING (
      auth.uid() = merchant_id AND
      EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'merchant')
    )
    WITH CHECK (
      auth.uid() = merchant_id AND
      EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'merchant')
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Merchants can delete their own scheduled orders"
    ON scheduled_orders FOR DELETE
    TO authenticated
    USING (
      auth.uid() = merchant_id AND
      EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'merchant')
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Admin access
DO $$ BEGIN
  CREATE POLICY "Admins can view all scheduled orders"
    ON scheduled_orders FOR SELECT
    TO authenticated
    USING (
      EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_scheduled_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER scheduled_orders_updated_at
  BEFORE UPDATE ON scheduled_orders
  FOR EACH ROW
  EXECUTE FUNCTION update_scheduled_orders_updated_at();

-- Comments
COMMENT ON TABLE scheduled_orders IS 'Stores orders scheduled for future delivery';
COMMENT ON COLUMN scheduled_orders.scheduled_at IS 'Timestamp when the order should be posted';
COMMENT ON COLUMN scheduled_orders.status IS 'Status: scheduled (waiting), posted (converted to order), failed (error during posting), cancelled (user cancelled)';

