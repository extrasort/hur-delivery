-- WhatsApp Automation System for Order Location Requests
-- This migration sets up the database structure for automated WhatsApp messaging

-- Create table to track WhatsApp location requests
CREATE TABLE IF NOT EXISTS whatsapp_location_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  customer_phone TEXT NOT NULL,
  message_sid TEXT, -- Twilio message SID
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'failed', 'location_received')),
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  delivered_at TIMESTAMPTZ,
  location_received_at TIMESTAMPTZ,
  customer_latitude DECIMAL(10,8),
  customer_longitude DECIMAL(11,8),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_whatsapp_requests_order_id ON whatsapp_location_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_requests_customer_phone ON whatsapp_location_requests(customer_phone);
CREATE INDEX IF NOT EXISTS idx_whatsapp_requests_status ON whatsapp_location_requests(status);

-- Enable RLS
ALTER TABLE whatsapp_location_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own whatsapp requests"
ON whatsapp_location_requests FOR SELECT
USING (
  order_id IN (
    SELECT id FROM orders 
    WHERE merchant_id = auth.uid() OR driver_id = auth.uid()
  )
);

-- Function to trigger WhatsApp message when order is created
CREATE OR REPLACE FUNCTION trigger_whatsapp_location_request()
RETURNS TRIGGER AS $$
DECLARE
  customer_phone TEXT;
BEGIN
  -- Get customer phone number from the new order
  customer_phone := NEW.customer_phone;
  
  -- Only trigger for new orders (not updates)
  IF TG_OP = 'INSERT' THEN
    -- Insert a record to track the WhatsApp request
    INSERT INTO whatsapp_location_requests (order_id, customer_phone)
    VALUES (NEW.id, customer_phone);
    
    -- Call the edge function to send WhatsApp message
    PERFORM net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/send-whatsapp-location-request',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
      ),
      body := jsonb_build_object(
        'order_id', NEW.id,
        'customer_phone', customer_phone,
        'customer_name', NEW.customer_name,
        'merchant_name', (
          SELECT name FROM users WHERE id = NEW.merchant_id
        )
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on orders table
DROP TRIGGER IF EXISTS trigger_order_whatsapp_request ON orders;
CREATE TRIGGER trigger_order_whatsapp_request
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_whatsapp_location_request();

-- Function to update order with customer location
CREATE OR REPLACE FUNCTION update_customer_location(
  p_order_id UUID,
  p_latitude DECIMAL(10,8),
  p_longitude DECIMAL(11,8)
)
RETURNS BOOLEAN AS $$
DECLARE
  order_exists BOOLEAN;
BEGIN
  -- Check if order exists
  SELECT EXISTS(SELECT 1 FROM orders WHERE id = p_order_id) INTO order_exists;
  
  IF NOT order_exists THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;
  
  -- Update the order with new customer location
  UPDATE orders 
  SET 
    delivery_latitude = p_latitude,
    delivery_longitude = p_longitude,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Update the WhatsApp request record
  UPDATE whatsapp_location_requests 
  SET 
    status = 'location_received',
    customer_latitude = p_latitude,
    customer_longitude = p_longitude,
    location_received_at = NOW(),
    updated_at = NOW()
  WHERE order_id = p_order_id;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION update_customer_location TO authenticated;
GRANT EXECUTE ON FUNCTION update_customer_location TO anon;

-- Add comments for documentation
COMMENT ON TABLE whatsapp_location_requests IS 'Tracks WhatsApp location requests sent to customers';
COMMENT ON FUNCTION trigger_whatsapp_location_request() IS 'Automatically sends WhatsApp location request when order is created';
COMMENT ON FUNCTION update_customer_location(UUID, DECIMAL, DECIMAL) IS 'Updates order with customer location coordinates received via WhatsApp';
