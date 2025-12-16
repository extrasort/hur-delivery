-- =====================================================================================
-- HUR DELIVERY SYSTEM - COMPLETE DATABASE SCHEMA
-- =====================================================================================
-- A comprehensive, production-ready database schema for a delivery app system
-- 
-- Features:
-- - Automatic driver assignment using PostGIS proximity
-- - 30-second auto-reject with reassignment
-- - Manual rejection with automatic next-driver assignment
-- - Full rejection history tracking
-- - Repost order with increased delivery fee (500 IQD)
-- - Complete RLS (Row Level Security) policies
-- - Manual user verification system
-- - Real-time subscriptions for all critical tables
-- - Comprehensive audit trails
-- - Earnings and payment tracking
-- - Location tracking for drivers
-- - Notification system
-- =====================================================================================

-- =====================================================================================
-- 1. EXTENSIONS
-- =====================================================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable PostGIS for geospatial calculations
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable pg_cron for scheduled tasks (if available)
-- Note: This may require superuser privileges
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- =====================================================================================
-- 2. CORE TABLES
-- =====================================================================================

-- -----------------------------------------------------------------------------
-- Users Table - Central table for all user types
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT auth.uid(),
  phone TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('merchant', 'driver', 'customer', 'admin')),
  
  -- Verification & Status
  manual_verified BOOLEAN DEFAULT FALSE,
  is_online BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  
  -- Location (for merchants and drivers)
  address TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  
  -- Communication
  fcm_token TEXT,
  
  -- Merchant-specific fields
  store_name TEXT,
  
  -- Driver-specific fields
  vehicle_type TEXT,
  vehicle_plate TEXT,
  has_driving_license BOOLEAN,
  owns_vehicle BOOLEAN,
  
  -- Document URLs (for verification)
  id_card_front_url TEXT,
  id_card_back_url TEXT,
  selfie_with_id_url TEXT,
  
  -- Metadata
  verification_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ,
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES users(id)
);

-- -----------------------------------------------------------------------------
-- Orders Table - Central table for all delivery orders
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Relationships
  merchant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES users(id) ON DELETE SET NULL,
  
  -- Customer Information
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  
  -- Pickup Location
  pickup_address TEXT NOT NULL,
  pickup_latitude DECIMAL(10,8) NOT NULL,
  pickup_longitude DECIMAL(11,8) NOT NULL,
  pickup_location GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(ST_MakePoint(pickup_longitude, pickup_latitude), 4326)::geography
  ) STORED,
  
  -- Delivery Location
  delivery_address TEXT NOT NULL,
  delivery_latitude DECIMAL(10,8) NOT NULL,
  delivery_longitude DECIMAL(11,8) NOT NULL,
  delivery_location GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(ST_MakePoint(delivery_longitude, delivery_latitude), 4326)::geography
  ) STORED,
  
  -- Status & Timeline
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'assigned', 'accepted', 'on_the_way', 'delivered', 'cancelled', 'rejected')
  ),
  
  -- Financial
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 5000,
  original_delivery_fee DECIMAL(10,2),
  repost_count INTEGER DEFAULT 0,
  
  -- Additional Info
  notes TEXT,
  cancellation_reason TEXT,
  rejection_reason TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  driver_assigned_at TIMESTAMPTZ,
  accepted_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ
);

-- -----------------------------------------------------------------------------
-- Order Items Table - Line items for orders
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  price DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- Order Rejected Drivers - Track which drivers rejected/timed out
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_rejected_drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('manual_reject', 'timeout', 'offline')),
  rejected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(order_id, driver_id)
);

-- -----------------------------------------------------------------------------
-- Order Assignments History - Complete audit trail of all assignments
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'accepted', 'rejected', 'timeout', 'cancelled')
  ),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  timeout_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 seconds'),
  responded_at TIMESTAMPTZ,
  response_time_seconds INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- Notifications Table - Push notifications and in-app alerts
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL CHECK (
    type IN ('order_assigned', 'order_accepted', 'order_status_update', 
             'order_delivered', 'order_cancelled', 'payment', 'system')
  ),
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- Driver Locations - Real-time driver location tracking
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS driver_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  latitude DECIMAL(10,8) NOT NULL,
  longitude DECIMAL(11,8) NOT NULL,
  location GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  ) STORED,
  accuracy DECIMAL(8,2),
  heading DECIMAL(8,2),
  speed DECIMAL(8,2),
  is_moving BOOLEAN DEFAULT FALSE,
  battery_level INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- Earnings Table - Track driver earnings and payments
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  commission DECIMAL(10,2) NOT NULL DEFAULT 0,
  net_amount DECIMAL(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'approved', 'paid', 'cancelled')
  ),
  payment_method TEXT,
  payment_reference TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ
);

-- -----------------------------------------------------------------------------
-- System Settings - Configurable system parameters
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS system_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  value_type TEXT NOT NULL DEFAULT 'string' CHECK (
    value_type IN ('string', 'number', 'boolean', 'json')
  ),
  description TEXT,
  is_public BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- Audit Log - Track all important system events
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================================================
-- 3. INDEXES FOR PERFORMANCE
-- =====================================================================================

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_online_verified ON users(is_online, manual_verified) WHERE role = 'driver';
CREATE INDEX IF NOT EXISTS idx_users_location_drivers ON users USING GIST (
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
) WHERE role = 'driver' AND latitude IS NOT NULL AND longitude IS NOT NULL;

-- Orders table indexes
CREATE INDEX IF NOT EXISTS idx_orders_merchant ON orders(merchant_id);
CREATE INDEX IF NOT EXISTS idx_orders_driver ON orders(driver_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_pending_with_driver ON orders(id, driver_id, driver_assigned_at) 
  WHERE status = 'pending' AND driver_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_location_pickup ON orders USING GIST (pickup_location);
CREATE INDEX IF NOT EXISTS idx_orders_location_delivery ON orders USING GIST (delivery_location);

-- Order items indexes
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

-- Order rejected drivers indexes
CREATE INDEX IF NOT EXISTS idx_rejected_drivers_order ON order_rejected_drivers(order_id);
CREATE INDEX IF NOT EXISTS idx_rejected_drivers_driver ON order_rejected_drivers(driver_id);

-- Order assignments indexes
CREATE INDEX IF NOT EXISTS idx_assignments_order ON order_assignments(order_id);
CREATE INDEX IF NOT EXISTS idx_assignments_driver ON order_assignments(driver_id);
CREATE INDEX IF NOT EXISTS idx_assignments_status ON order_assignments(status);

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- Driver locations indexes
CREATE INDEX IF NOT EXISTS idx_driver_locations_driver ON driver_locations(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_locations_created ON driver_locations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_locations_location ON driver_locations USING GIST (location);

-- Earnings indexes
CREATE INDEX IF NOT EXISTS idx_earnings_driver ON earnings(driver_id);
CREATE INDEX IF NOT EXISTS idx_earnings_order ON earnings(order_id);
CREATE INDEX IF NOT EXISTS idx_earnings_status ON earnings(status);

-- Audit log indexes
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON audit_log(created_at DESC);

-- =====================================================================================
-- 4. HELPER FUNCTIONS
-- =====================================================================================

-- -----------------------------------------------------------------------------
-- Find Next Available Driver (PostGIS-powered proximity search)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION find_next_available_driver(
  p_order_id UUID,
  p_pickup_lat DECIMAL,
  p_pickup_lng DECIMAL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_point GEOGRAPHY;
BEGIN
  -- Create geography point for pickup location
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  -- TIER 1: Try to find driver with NO active orders at all (completely free)
  SELECT u.id INTO v_driver_id
  FROM users u
  WHERE u.role = 'driver'
    AND u.is_online = TRUE
    AND u.manual_verified = TRUE
    AND u.is_active = TRUE
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
    -- Driver hasn't rejected this order
    AND u.id NOT IN (
      SELECT driver_id 
      FROM order_rejected_drivers 
      WHERE order_id = p_order_id
    )
    -- Driver has NO active orders at all (completely free)
    AND u.id NOT IN (
      SELECT driver_id 
      FROM orders 
      WHERE driver_id IS NOT NULL 
        AND status IN ('pending', 'accepted', 'on_the_way')
    )
  ORDER BY ST_Distance(
    v_pickup_point,
    ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
  ) ASC
  LIMIT 1;
  
  -- TIER 2: If no completely free driver found, try drivers with only pending orders
  IF v_driver_id IS NULL THEN
    SELECT u.id INTO v_driver_id
    FROM users u
    WHERE u.role = 'driver'
      AND u.is_online = TRUE
      AND u.manual_verified = TRUE
      AND u.is_active = TRUE
      AND u.latitude IS NOT NULL
      AND u.longitude IS NOT NULL
      -- Driver hasn't rejected this order
      AND u.id NOT IN (
        SELECT driver_id 
        FROM order_rejected_drivers 
        WHERE order_id = p_order_id
      )
      -- Driver doesn't have accepted/on_the_way orders (but may have pending)
      AND u.id NOT IN (
        SELECT driver_id 
        FROM orders 
        WHERE driver_id IS NOT NULL 
          AND status IN ('accepted', 'on_the_way')
      )
    ORDER BY ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) ASC
    LIMIT 1;
  END IF;
  
  RETURN v_driver_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- Get Ranked Available Drivers (for debugging/admin panel)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_ranked_available_drivers(
  p_order_id UUID,
  p_pickup_lat DECIMAL,
  p_pickup_lng DECIMAL,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  driver_id UUID,
  driver_name TEXT,
  distance_meters DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  latitude DECIMAL,
  longitude DECIMAL,
  is_online BOOLEAN,
  has_rejected BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pickup_point GEOGRAPHY;
BEGIN
  v_pickup_point := ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography;
  
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) as dist_meters,
    ST_Distance(
      v_pickup_point,
      ST_SetSRID(ST_MakePoint(u.longitude, u.latitude), 4326)::geography
    ) / 1000.0 as dist_km,
    u.latitude,
    u.longitude,
    u.is_online,
    EXISTS(
      SELECT 1 FROM order_rejected_drivers 
      WHERE order_id = p_order_id AND driver_id = u.id
    ) as rejected
  FROM users u
  WHERE u.role = 'driver'
    AND u.manual_verified = TRUE
    AND u.is_active = TRUE
    AND u.latitude IS NOT NULL
    AND u.longitude IS NOT NULL
  ORDER BY dist_meters ASC
  LIMIT p_limit;
END;
$$;

-- =====================================================================================
-- 5. CORE BUSINESS LOGIC FUNCTIONS
-- =====================================================================================

-- -----------------------------------------------------------------------------
-- Auto-Assign Order to Nearest Driver
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_assign_order(p_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_driver_id UUID;
  v_pickup_lat DECIMAL;
  v_pickup_lng DECIMAL;
  v_order_status TEXT;
  v_current_driver UUID;
  v_rejection_count INTEGER;
BEGIN
  -- Get order details
  SELECT status, pickup_latitude, pickup_longitude, driver_id
  INTO v_order_status, v_pickup_lat, v_pickup_lng, v_current_driver
  FROM orders
  WHERE id = p_order_id;
  
  -- Only assign if order is pending
  IF v_order_status != 'pending' THEN
    RAISE NOTICE 'Order % is not pending (status: %)', p_order_id, v_order_status;
    RETURN FALSE;
  END IF;
  
  -- Check if order already has a driver assigned
  IF v_current_driver IS NOT NULL THEN
    RAISE NOTICE 'Order % already has driver %', p_order_id, v_current_driver;
    RETURN FALSE;
  END IF;
  
  -- Count how many drivers have rejected this order
  SELECT COUNT(*) INTO v_rejection_count
  FROM order_rejected_drivers
  WHERE order_id = p_order_id;
  
  -- Find next available driver
  v_driver_id := find_next_available_driver(p_order_id, v_pickup_lat, v_pickup_lng);
  
  IF v_driver_id IS NULL THEN
    -- No available drivers - mark order as rejected
    RAISE NOTICE 'No available drivers for order %. Total rejections: %', p_order_id, v_rejection_count;
    
    UPDATE orders
    SET 
      status = 'rejected',
      rejected_at = NOW(),
      rejection_reason = 'No available drivers',
      updated_at = NOW()
    WHERE id = p_order_id;
    
    -- Notify merchant
    INSERT INTO notifications (user_id, title, body, type, data)
    SELECT 
      merchant_id,
      'تم رفض الطلب',
      'لم يتم العثور على سائق متاح. يمكنك إعادة نشر الطلب بزيادة أجرة التوصيل.',
      'order_cancelled',
      jsonb_build_object('order_id', p_order_id, 'repost_available', true)
    FROM orders
    WHERE id = p_order_id;
    
    RETURN FALSE;
  END IF;
  
  -- Assign order to driver
  UPDATE orders
  SET 
    driver_id = v_driver_id,
    driver_assigned_at = NOW(),
    updated_at = NOW()
  WHERE id = p_order_id
    AND status = 'pending'
    AND driver_id IS NULL;
  
  IF FOUND THEN
    -- Create assignment record
    INSERT INTO order_assignments (order_id, driver_id, status)
    VALUES (p_order_id, v_driver_id, 'pending');
    
    -- Notify driver
    INSERT INTO notifications (user_id, title, body, type, data)
    VALUES (
      v_driver_id,
      'طلب توصيل جديد',
      'لديك طلب توصيل جديد. يرجى القبول أو الرفض خلال 30 ثانية.',
      'order_assigned',
      jsonb_build_object('order_id', p_order_id, 'timeout_seconds', 30)
    );
    
    RAISE NOTICE 'Assigned order % to driver %', p_order_id, v_driver_id;
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- Driver Accepts Order
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION driver_accept_order(
  p_order_id UUID,
  p_driver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_status TEXT;
  v_assigned_driver UUID;
  v_response_time INTEGER;
BEGIN
  -- Get order details
  SELECT status, driver_id INTO v_order_status, v_assigned_driver
  FROM orders
  WHERE id = p_order_id;
  
  -- Validate order status
  IF v_order_status != 'pending' THEN
    RAISE EXCEPTION 'Order is not pending (status: %)', v_order_status;
  END IF;
  
  -- Validate driver assignment
  IF v_assigned_driver != p_driver_id THEN
    RAISE EXCEPTION 'Order is not assigned to this driver';
  END IF;
  
  -- Calculate response time
  SELECT EXTRACT(EPOCH FROM (NOW() - driver_assigned_at))::INTEGER
  INTO v_response_time
  FROM orders
  WHERE id = p_order_id;
  
  -- Update order status
  UPDATE orders
  SET 
    status = 'accepted',
    accepted_at = NOW(),
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Update assignment record
  UPDATE order_assignments
  SET 
    status = 'accepted',
    responded_at = NOW(),
    response_time_seconds = v_response_time
  WHERE order_id = p_order_id AND driver_id = p_driver_id AND status = 'pending';
  
  -- Notify merchant
  INSERT INTO notifications (user_id, title, body, type, data)
  SELECT 
    merchant_id,
    'تم قبول الطلب',
    'قبل السائق طلبك وهو في طريقه للاستلام.',
    'order_accepted',
    jsonb_build_object('order_id', p_order_id, 'driver_id', p_driver_id)
  FROM orders
  WHERE id = p_order_id;
  
  RAISE NOTICE 'Driver % accepted order % in % seconds', p_driver_id, p_order_id, v_response_time;
  RETURN TRUE;
END;
$$;

-- -----------------------------------------------------------------------------
-- Driver Rejects Order (with auto-reassignment)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION driver_reject_order(
  p_order_id UUID,
  p_driver_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_status TEXT;
  v_assigned_driver UUID;
  v_response_time INTEGER;
BEGIN
  -- Get order details
  SELECT status, driver_id INTO v_order_status, v_assigned_driver
  FROM orders
  WHERE id = p_order_id;
  
  -- Validate order status
  IF v_order_status != 'pending' THEN
    RAISE NOTICE 'Order % is not pending (status: %)', p_order_id, v_order_status;
    RETURN FALSE;
  END IF;
  
  -- Validate driver assignment
  IF v_assigned_driver != p_driver_id THEN
    RAISE NOTICE 'Order % is not assigned to driver %', p_order_id, p_driver_id;
    RETURN FALSE;
  END IF;
  
  -- Calculate response time
  SELECT EXTRACT(EPOCH FROM (NOW() - driver_assigned_at))::INTEGER
  INTO v_response_time
  FROM orders
  WHERE id = p_order_id;
  
  -- Add driver to rejected list
  INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
  VALUES (p_order_id, p_driver_id, 'manual_reject')
  ON CONFLICT (order_id, driver_id) DO NOTHING;
  
  -- Update assignment record
  UPDATE order_assignments
  SET 
    status = 'rejected',
    responded_at = NOW(),
    response_time_seconds = v_response_time
  WHERE order_id = p_order_id AND driver_id = p_driver_id AND status = 'pending';
  
  -- Remove driver from order
  UPDATE orders
  SET 
    driver_id = NULL,
    driver_assigned_at = NULL,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Try to assign to next available driver
  PERFORM auto_assign_order(p_order_id);
  
  RAISE NOTICE 'Driver % rejected order % after % seconds. Reassigning...', 
    p_driver_id, p_order_id, v_response_time;
  
  RETURN TRUE;
END;
$$;

-- -----------------------------------------------------------------------------
-- Auto-Reject Expired Orders (30-second timeout)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auto_reject_expired_orders()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_order RECORD;
  v_count INTEGER := 0;
BEGIN
  -- Loop through all expired orders
  FOR expired_order IN
    SELECT id, driver_id, driver_assigned_at
    FROM orders
    WHERE status = 'pending'
      AND driver_id IS NOT NULL
      AND driver_assigned_at IS NOT NULL
      AND driver_assigned_at < (NOW() - INTERVAL '30 seconds')
  LOOP
    -- Add driver to rejected list for timeout
    INSERT INTO order_rejected_drivers (order_id, driver_id, reason)
    VALUES (expired_order.id, expired_order.driver_id, 'timeout')
    ON CONFLICT (order_id, driver_id) DO NOTHING;
    
    -- Update assignment record
    UPDATE order_assignments
    SET status = 'timeout', responded_at = NOW()
    WHERE order_id = expired_order.id 
      AND driver_id = expired_order.driver_id 
      AND status = 'pending';
    
    -- Remove driver from order
    UPDATE orders
    SET 
      driver_id = NULL,
      driver_assigned_at = NULL,
      updated_at = NOW()
    WHERE id = expired_order.id;
    
    -- Try to assign to next available driver
    PERFORM auto_assign_order(expired_order.id);
    
    v_count := v_count + 1;
    
    RAISE NOTICE 'Driver % timed out on order %. Reassigning...', 
      expired_order.driver_id, expired_order.id;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- -----------------------------------------------------------------------------
-- Repost Rejected Order with Increased Fee
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION repost_order_with_increased_fee(
  p_order_id UUID,
  p_merchant_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_status TEXT;
  v_merchant_id UUID;
  v_current_fee DECIMAL;
  v_new_fee DECIMAL;
  v_repost_count INTEGER;
BEGIN
  -- Get order details
  SELECT status, merchant_id, delivery_fee, repost_count
  INTO v_order_status, v_merchant_id, v_current_fee, v_repost_count
  FROM orders
  WHERE id = p_order_id;
  
  -- Validate merchant
  IF v_merchant_id != p_merchant_id THEN
    RAISE EXCEPTION 'Unauthorized: Order does not belong to this merchant';
  END IF;
  
  -- Validate order status
  IF v_order_status != 'rejected' THEN
    RAISE EXCEPTION 'Order is not rejected (status: %)', v_order_status;
  END IF;
  
  -- Calculate new delivery fee (increase by 500 IQD)
  v_new_fee := v_current_fee + 500;
  
  -- Update order
  UPDATE orders
  SET 
    status = 'pending',
    delivery_fee = v_new_fee,
    original_delivery_fee = COALESCE(original_delivery_fee, v_current_fee),
    repost_count = v_repost_count + 1,
    driver_id = NULL,
    driver_assigned_at = NULL,
    rejected_at = NULL,
    rejection_reason = NULL,
    updated_at = NOW()
  WHERE id = p_order_id;
  
  -- Clear rejected drivers (give them another chance with higher fee)
  DELETE FROM order_rejected_drivers WHERE order_id = p_order_id;
  
  -- Try to auto-assign
  PERFORM auto_assign_order(p_order_id);
  
  RAISE NOTICE 'Order % reposted with new fee: % IQD (was % IQD)', 
    p_order_id, v_new_fee, v_current_fee;
  
  RETURN TRUE;
END;
$$;

-- -----------------------------------------------------------------------------
-- Update Order Status (with validation)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id UUID,
  p_new_status TEXT,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_status TEXT;
  v_driver_id UUID;
  v_merchant_id UUID;
  v_user_role TEXT;
  v_delivery_fee DECIMAL;
BEGIN
  -- Get order details
  SELECT status, driver_id, merchant_id, delivery_fee
  INTO v_current_status, v_driver_id, v_merchant_id, v_delivery_fee
  FROM orders
  WHERE id = p_order_id;
  
  -- Get user role
  SELECT role INTO v_user_role FROM users WHERE id = p_user_id;
  
  -- Validate status transition
  IF v_current_status = 'delivered' OR v_current_status = 'cancelled' THEN
    RAISE EXCEPTION 'Cannot update completed order';
  END IF;
  
  -- Validate permissions
  IF v_user_role = 'driver' AND v_driver_id != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: Order not assigned to this driver';
  END IF;
  
  IF v_user_role = 'merchant' AND v_merchant_id != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: Order does not belong to this merchant';
  END IF;
  
  -- Update order status
  UPDATE orders
  SET 
    status = p_new_status,
    updated_at = NOW(),
    picked_up_at = CASE WHEN p_new_status = 'on_the_way' THEN NOW() ELSE picked_up_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE delivered_at END,
    cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN NOW() ELSE cancelled_at END
  WHERE id = p_order_id;
  
  -- Create earnings when order is delivered
  IF p_new_status = 'delivered' AND v_current_status != 'delivered' THEN
    INSERT INTO earnings (driver_id, order_id, amount, commission, net_amount)
    SELECT 
      v_driver_id,
      p_order_id,
      v_delivery_fee,
      v_delivery_fee * 0.1, -- 10% commission
      v_delivery_fee * 0.9  -- 90% to driver
    WHERE v_driver_id IS NOT NULL;
  END IF;
  
  -- Send notification
  INSERT INTO notifications (user_id, title, body, type, data)
  VALUES (
    CASE WHEN v_user_role = 'driver' THEN v_merchant_id ELSE v_driver_id END,
    'تحديث حالة الطلب',
    'تم تحديث حالة الطلب إلى: ' || p_new_status,
    'order_status_update',
    jsonb_build_object('order_id', p_order_id, 'status', p_new_status)
  );
  
  RETURN TRUE;
END;
$$;

-- -----------------------------------------------------------------------------
-- Update Driver Location
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_driver_location(
  p_driver_id UUID,
  p_latitude DECIMAL,
  p_longitude DECIMAL,
  p_accuracy DECIMAL DEFAULT NULL,
  p_heading DECIMAL DEFAULT NULL,
  p_speed DECIMAL DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Insert new location record
  INSERT INTO driver_locations (
    driver_id, latitude, longitude, accuracy, heading, speed, is_moving
  )
  VALUES (
    p_driver_id, p_latitude, p_longitude, p_accuracy, p_heading, p_speed,
    CASE WHEN p_speed IS NOT NULL AND p_speed > 0.5 THEN TRUE ELSE FALSE END
  );
  
  -- Update user's current location
  UPDATE users
  SET 
    latitude = p_latitude,
    longitude = p_longitude,
    updated_at = NOW(),
    last_seen_at = NOW()
  WHERE id = p_driver_id;
  
  RETURN TRUE;
END;
$$;

-- =====================================================================================
-- 6. TRIGGERS
-- =====================================================================================

-- -----------------------------------------------------------------------------
-- Trigger: Auto-assign driver when order is created
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_auto_assign_on_create()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only auto-assign if order is pending and has no driver
  IF NEW.status = 'pending' AND NEW.driver_id IS NULL THEN
    PERFORM auto_assign_order(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_assign_new_orders ON orders;
CREATE TRIGGER auto_assign_new_orders
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_auto_assign_on_create();

-- -----------------------------------------------------------------------------
-- Trigger: Update updated_at timestamp
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_users_timestamp ON users;
CREATE TRIGGER update_users_timestamp
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_timestamp();

DROP TRIGGER IF EXISTS update_orders_timestamp ON orders;
CREATE TRIGGER update_orders_timestamp
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_timestamp();

DROP TRIGGER IF EXISTS update_system_settings_timestamp ON system_settings;
CREATE TRIGGER update_system_settings_timestamp
  BEFORE UPDATE ON system_settings
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_timestamp();

-- -----------------------------------------------------------------------------
-- Trigger: Create audit log entries
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO audit_log (
    user_id, action, entity_type, entity_id, old_data, new_data
  )
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD) ELSE NULL END,
    CASE WHEN TG_OP != 'DELETE' THEN row_to_json(NEW) ELSE NULL END
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Apply audit logging to critical tables
DROP TRIGGER IF EXISTS audit_orders ON orders;
CREATE TRIGGER audit_orders
  AFTER INSERT OR UPDATE OR DELETE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_audit_log();

DROP TRIGGER IF EXISTS audit_users ON users;
CREATE TRIGGER audit_users
  AFTER UPDATE ON users
  FOR EACH ROW
  WHEN (OLD.manual_verified IS DISTINCT FROM NEW.manual_verified)
  EXECUTE FUNCTION trigger_audit_log();

-- =====================================================================================
-- 7. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_rejected_drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Users Table Policies
-- -----------------------------------------------------------------------------

-- Users can view their own profile
CREATE POLICY "users_view_own" ON users
  FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "users_update_own" ON users
  FOR UPDATE
  USING (auth.uid() = id);

-- Admins can view all users
CREATE POLICY "users_admin_view_all" ON users
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update all users (for verification)
CREATE POLICY "users_admin_update_all" ON users
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Drivers can view other online drivers (for chat/coordination)
CREATE POLICY "users_drivers_view_online_drivers" ON users
  FOR SELECT
  USING (
    role = 'driver' AND is_online = TRUE AND
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'driver'
    )
  );

-- System can insert new users (signup)
CREATE POLICY "users_insert_authenticated" ON users
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- -----------------------------------------------------------------------------
-- Orders Table Policies
-- -----------------------------------------------------------------------------

-- Merchants can view their own orders
CREATE POLICY "orders_merchant_view_own" ON orders
  FOR SELECT
  USING (merchant_id = auth.uid());

-- Merchants can create orders
CREATE POLICY "orders_merchant_create" ON orders
  FOR INSERT
  WITH CHECK (merchant_id = auth.uid());

-- Merchants can update their own orders (cancel, etc.)
CREATE POLICY "orders_merchant_update_own" ON orders
  FOR UPDATE
  USING (merchant_id = auth.uid());

-- Drivers can view orders assigned to them or pending orders
CREATE POLICY "orders_driver_view_assigned_or_pending" ON orders
  FOR SELECT
  USING (
    driver_id = auth.uid() OR
    (status = 'pending' AND EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'driver' AND is_online = TRUE AND manual_verified = TRUE
    ))
  );

-- Drivers can update orders assigned to them
CREATE POLICY "orders_driver_update_assigned" ON orders
  FOR UPDATE
  USING (driver_id = auth.uid());

-- Admins can view all orders
CREATE POLICY "orders_admin_view_all" ON orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- System functions can update orders (for auto-assignment)
CREATE POLICY "orders_system_update" ON orders
  FOR UPDATE
  USING (TRUE);

-- -----------------------------------------------------------------------------
-- Order Items Table Policies
-- -----------------------------------------------------------------------------

-- View items if user can view the order
CREATE POLICY "order_items_view_with_order" ON order_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE id = order_items.order_id 
        AND (merchant_id = auth.uid() OR driver_id = auth.uid())
    )
  );

-- Merchants can create items for their orders
CREATE POLICY "order_items_merchant_create" ON order_items
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE id = order_items.order_id AND merchant_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- Order Rejected Drivers Table Policies
-- -----------------------------------------------------------------------------

-- System can insert/update rejection records
CREATE POLICY "rejected_drivers_system" ON order_rejected_drivers
  FOR ALL
  USING (TRUE)
  WITH CHECK (TRUE);

-- Drivers can view their own rejections
CREATE POLICY "rejected_drivers_driver_view_own" ON order_rejected_drivers
  FOR SELECT
  USING (driver_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Order Assignments Table Policies
-- -----------------------------------------------------------------------------

-- Drivers can view their assignments
CREATE POLICY "assignments_driver_view_own" ON order_assignments
  FOR SELECT
  USING (driver_id = auth.uid());

-- Merchants can view assignments for their orders
CREATE POLICY "assignments_merchant_view_own" ON order_assignments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE id = order_assignments.order_id AND merchant_id = auth.uid()
    )
  );

-- System can create/update assignments
CREATE POLICY "assignments_system" ON order_assignments
  FOR ALL
  USING (TRUE)
  WITH CHECK (TRUE);

-- -----------------------------------------------------------------------------
-- Notifications Table Policies
-- -----------------------------------------------------------------------------

-- Users can view their own notifications
CREATE POLICY "notifications_view_own" ON notifications
  FOR SELECT
  USING (user_id = auth.uid());

-- Users can update their own notifications (mark as read)
CREATE POLICY "notifications_update_own" ON notifications
  FOR UPDATE
  USING (user_id = auth.uid());

-- System can create notifications
CREATE POLICY "notifications_system_create" ON notifications
  FOR INSERT
  WITH CHECK (TRUE);

-- -----------------------------------------------------------------------------
-- Driver Locations Table Policies
-- -----------------------------------------------------------------------------

-- Drivers can insert their own locations
CREATE POLICY "driver_locations_driver_insert_own" ON driver_locations
  FOR INSERT
  WITH CHECK (driver_id = auth.uid());

-- Drivers can view their own locations
CREATE POLICY "driver_locations_driver_view_own" ON driver_locations
  FOR SELECT
  USING (driver_id = auth.uid());

-- Merchants can view driver locations for their active orders
CREATE POLICY "driver_locations_merchant_view_order_driver" ON driver_locations
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE driver_id = driver_locations.driver_id 
        AND merchant_id = auth.uid()
        AND status IN ('accepted', 'on_the_way')
    )
  );

-- -----------------------------------------------------------------------------
-- Earnings Table Policies
-- -----------------------------------------------------------------------------

-- Drivers can view their own earnings
CREATE POLICY "earnings_driver_view_own" ON earnings
  FOR SELECT
  USING (driver_id = auth.uid());

-- System can create earnings
CREATE POLICY "earnings_system_create" ON earnings
  FOR INSERT
  WITH CHECK (TRUE);

-- Admins can view all earnings
CREATE POLICY "earnings_admin_view_all" ON earnings
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update earnings (approve/pay)
CREATE POLICY "earnings_admin_update" ON earnings
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- -----------------------------------------------------------------------------
-- System Settings Table Policies
-- -----------------------------------------------------------------------------

-- Public settings can be viewed by all authenticated users
CREATE POLICY "system_settings_view_public" ON system_settings
  FOR SELECT
  USING (is_public = TRUE);

-- Admins can view all settings
CREATE POLICY "system_settings_admin_view_all" ON system_settings
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update settings
CREATE POLICY "system_settings_admin_update" ON system_settings
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- -----------------------------------------------------------------------------
-- Audit Log Table Policies
-- -----------------------------------------------------------------------------

-- Admins can view audit logs
CREATE POLICY "audit_log_admin_view" ON audit_log
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- System can create audit logs
CREATE POLICY "audit_log_system_create" ON audit_log
  FOR INSERT
  WITH CHECK (TRUE);

-- =====================================================================================
-- 8. DEFAULT DATA & SETTINGS
-- =====================================================================================

-- Insert default system settings
INSERT INTO system_settings (key, value, value_type, description, is_public) VALUES
  ('default_delivery_fee', '5000', 'number', 'Default delivery fee in IQD', TRUE),
  ('commission_rate', '0.1', 'number', 'Commission rate (10%)', FALSE),
  ('order_timeout_seconds', '30', 'number', 'Order assignment timeout in seconds', TRUE),
  ('max_delivery_distance_km', '50', 'number', 'Maximum delivery distance in kilometers', TRUE),
  ('repost_fee_increase', '500', 'number', 'Fee increase when reposting rejected order (IQD)', TRUE),
  ('app_version', '1.0.0', 'string', 'Current app version', TRUE),
  ('maintenance_mode', 'false', 'boolean', 'Maintenance mode status', TRUE),
  ('min_driver_rating', '3.0', 'number', 'Minimum driver rating to receive orders', FALSE),
  ('support_phone', '+964771234567', 'string', 'Support phone number (WhatsApp)', TRUE),
  ('support_email', 'support@hur.delivery', 'string', 'Support email address', TRUE)
ON CONFLICT (key) DO NOTHING;

-- =====================================================================================
-- 9. VIEWS & ANALYTICS
-- =====================================================================================

-- -----------------------------------------------------------------------------
-- Order Details View (with all related data)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW order_details AS
SELECT 
  o.id,
  o.merchant_id,
  o.driver_id,
  o.customer_name,
  o.customer_phone,
  o.pickup_address,
  o.pickup_latitude,
  o.pickup_longitude,
  o.delivery_address,
  o.delivery_latitude,
  o.delivery_longitude,
  o.status,
  o.total_amount,
  o.delivery_fee,
  o.original_delivery_fee,
  o.repost_count,
  o.notes,
  o.created_at,
  o.updated_at,
  o.driver_assigned_at,
  o.accepted_at,
  o.delivered_at,
  m.name as merchant_name,
  m.store_name,
  m.phone as merchant_phone,
  d.name as driver_name,
  d.phone as driver_phone,
  d.vehicle_type,
  COALESCE(
    json_agg(
      json_build_object(
        'id', oi.id,
        'name', oi.name,
        'quantity', oi.quantity,
        'price', oi.price
      )
    ) FILTER (WHERE oi.id IS NOT NULL),
    '[]'
  ) as items
FROM orders o
JOIN users m ON o.merchant_id = m.id
LEFT JOIN users d ON o.driver_id = d.id
LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY 
  o.id, o.merchant_id, o.driver_id, o.customer_name, o.customer_phone,
  o.pickup_address, o.pickup_latitude, o.pickup_longitude,
  o.delivery_address, o.delivery_latitude, o.delivery_longitude,
  o.status, o.total_amount, o.delivery_fee, o.original_delivery_fee, 
  o.repost_count, o.notes, o.created_at, o.updated_at,
  o.driver_assigned_at, o.accepted_at, o.delivered_at,
  m.name, m.store_name, m.phone, d.name, d.phone, d.vehicle_type;

-- -----------------------------------------------------------------------------
-- Driver Statistics View
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW driver_stats AS
SELECT 
  d.id as driver_id,
  d.name as driver_name,
  d.phone as driver_phone,
  d.is_online,
  d.manual_verified,
  COUNT(o.id) as total_orders,
  COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as completed_orders,
  COUNT(CASE WHEN oa.status = 'accepted' THEN 1 END) as accepted_orders,
  COUNT(CASE WHEN oa.status = 'rejected' THEN 1 END) as rejected_orders,
  COUNT(CASE WHEN oa.status = 'timeout' THEN 1 END) as timeout_orders,
  COALESCE(
    ROUND(
      COUNT(CASE WHEN oa.status = 'accepted' THEN 1 END)::NUMERIC / 
      NULLIF(COUNT(oa.id), 0) * 100, 
      2
    ), 
    0
  ) as acceptance_rate,
  COALESCE(AVG(oa.response_time_seconds), 0)::INTEGER as avg_response_time_seconds,
  COALESCE(SUM(e.net_amount) FILTER (WHERE e.status = 'pending'), 0) as pending_earnings,
  COALESCE(SUM(e.net_amount) FILTER (WHERE e.status = 'paid'), 0) as paid_earnings,
  COALESCE(SUM(e.net_amount), 0) as total_earnings
FROM users d
LEFT JOIN orders o ON d.id = o.driver_id
LEFT JOIN order_assignments oa ON d.id = oa.driver_id
LEFT JOIN earnings e ON d.id = e.driver_id
WHERE d.role = 'driver'
GROUP BY d.id, d.name, d.phone, d.is_online, d.manual_verified;

-- -----------------------------------------------------------------------------
-- Merchant Statistics View
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW merchant_stats AS
SELECT 
  m.id as merchant_id,
  m.name as merchant_name,
  m.store_name,
  m.phone as merchant_phone,
  COUNT(o.id) as total_orders,
  COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as completed_orders,
  COUNT(CASE WHEN o.status = 'cancelled' THEN 1 END) as cancelled_orders,
  COUNT(CASE WHEN o.status = 'rejected' THEN 1 END) as rejected_orders,
  COALESCE(SUM(o.total_amount) FILTER (WHERE o.status = 'delivered'), 0) as total_sales,
  COALESCE(SUM(o.delivery_fee) FILTER (WHERE o.status = 'delivered'), 0) as total_delivery_fees,
  COALESCE(AVG(o.total_amount) FILTER (WHERE o.status = 'delivered'), 0) as avg_order_value,
  COALESCE(AVG(o.delivery_fee) FILTER (WHERE o.status = 'delivered'), 0) as avg_delivery_fee
FROM users m
LEFT JOIN orders o ON m.id = o.merchant_id
WHERE m.role = 'merchant'
GROUP BY m.id, m.name, m.store_name, m.phone;

-- =====================================================================================
-- 10. UTILITY FUNCTIONS & ADMIN TOOLS
-- =====================================================================================

-- -----------------------------------------------------------------------------
-- Manual Driver Verification (Admin function)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin_verify_user(
  p_user_id UUID,
  p_admin_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role TEXT;
BEGIN
  -- Verify admin
  SELECT role INTO v_admin_role FROM users WHERE id = p_admin_id;
  
  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can verify users';
  END IF;
  
  -- Update user
  UPDATE users
  SET 
    manual_verified = TRUE,
    verified_at = NOW(),
    verified_by = p_admin_id,
    verification_notes = p_notes,
    updated_at = NOW()
  WHERE id = p_user_id;
  
  -- Send notification
  INSERT INTO notifications (user_id, title, body, type)
  VALUES (
    p_user_id,
    'تم التحقق من حسابك',
    'تم التحقق من حسابك بنجاح. يمكنك الآن البدء في استخدام التطبيق.',
    'system'
  );
  
  RETURN TRUE;
END;
$$;

-- -----------------------------------------------------------------------------
-- Get System Statistics (Admin dashboard)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_system_statistics()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'total_users', (SELECT COUNT(*) FROM users),
    'total_merchants', (SELECT COUNT(*) FROM users WHERE role = 'merchant'),
    'total_drivers', (SELECT COUNT(*) FROM users WHERE role = 'driver'),
    'online_drivers', (SELECT COUNT(*) FROM users WHERE role = 'driver' AND is_online = TRUE),
    'verified_drivers', (SELECT COUNT(*) FROM users WHERE role = 'driver' AND manual_verified = TRUE),
    'pending_verification', (SELECT COUNT(*) FROM users WHERE manual_verified = FALSE),
    'total_orders', (SELECT COUNT(*) FROM orders),
    'pending_orders', (SELECT COUNT(*) FROM orders WHERE status = 'pending'),
    'active_orders', (SELECT COUNT(*) FROM orders WHERE status IN ('assigned', 'accepted', 'on_the_way')),
    'completed_orders', (SELECT COUNT(*) FROM orders WHERE status = 'delivered'),
    'rejected_orders', (SELECT COUNT(*) FROM orders WHERE status = 'rejected'),
    'total_earnings', (SELECT COALESCE(SUM(net_amount), 0) FROM earnings),
    'pending_payments', (SELECT COALESCE(SUM(net_amount), 0) FROM earnings WHERE status = 'pending'),
    'today_orders', (SELECT COUNT(*) FROM orders WHERE created_at >= CURRENT_DATE),
    'today_revenue', (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE created_at >= CURRENT_DATE AND status = 'delivered')
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;

-- -----------------------------------------------------------------------------
-- Cleanup Old Data (Maintenance function)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cleanup_old_data()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_locations INTEGER;
  v_deleted_notifications INTEGER;
BEGIN
  -- Delete driver locations older than 7 days
  DELETE FROM driver_locations 
  WHERE created_at < NOW() - INTERVAL '7 days';
  GET DIAGNOSTICS v_deleted_locations = ROW_COUNT;
  
  -- Delete read notifications older than 30 days
  DELETE FROM notifications 
  WHERE is_read = TRUE AND created_at < NOW() - INTERVAL '30 days';
  GET DIAGNOSTICS v_deleted_notifications = ROW_COUNT;
  
  RETURN format('Deleted %s location records and %s notification records', 
    v_deleted_locations, v_deleted_notifications);
END;
$$;

-- =====================================================================================
-- 11. REALTIME PUBLICATION (Enable real-time subscriptions)
-- =====================================================================================

-- Drop existing publication if it exists
-- DO $$ BEGIN
--   DROP PUBLICATION IF EXISTS supabase_realtime;
-- EXCEPTION
--   WHEN undefined_object THEN NULL;
-- END $$;

-- Create publication for real-time tables
-- CREATE PUBLICATION supabase_realtime FOR TABLE 
--   orders,
--   order_assignments,
--   notifications,
--   driver_locations,
--   users;

-- Note: The above is usually handled by Supabase automatically
-- But we enable it explicitly for these tables

-- =====================================================================================
-- 12. SCHEDULED JOBS (Requires pg_cron extension)
-- =====================================================================================

-- Schedule auto-reject expired orders every 5 seconds
-- This requires pg_cron extension and superuser privileges
-- You may need to run this separately or use Supabase Edge Functions

-- NOTE: pg_cron scheduling is disabled by default
-- To enable, uncomment and run the following in a separate query:
--
-- SELECT cron.schedule(
--   'auto-reject-expired-orders',
--   '*/5 * * * * *',
--   'SELECT auto_reject_expired_orders();'
-- );
--
-- Or use Supabase Edge Functions (recommended)
-- See: supabase/functions/auto-reject-orders/README.md

-- =====================================================================================
-- 13. GRANT PERMISSIONS
-- =====================================================================================

-- Grant permissions to authenticated users
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- =====================================================================================
-- 14. COMMENTS & DOCUMENTATION
-- =====================================================================================

COMMENT ON TABLE users IS 'All app users (merchants, drivers, customers, admins)';
COMMENT ON TABLE orders IS 'Delivery orders with status tracking and location data';
COMMENT ON TABLE order_items IS 'Line items for each order';
COMMENT ON TABLE order_rejected_drivers IS 'Tracks which drivers rejected or timed out on each order';
COMMENT ON TABLE order_assignments IS 'Complete history of all order-driver assignments';
COMMENT ON TABLE notifications IS 'Push notifications and in-app alerts';
COMMENT ON TABLE driver_locations IS 'Real-time GPS tracking for drivers';
COMMENT ON TABLE earnings IS 'Driver earnings and payment tracking';
COMMENT ON TABLE system_settings IS 'Configurable system parameters';
COMMENT ON TABLE audit_log IS 'Audit trail of all important system events';

COMMENT ON FUNCTION find_next_available_driver IS 
  'Finds nearest available driver using PostGIS distance calculation';

COMMENT ON FUNCTION auto_assign_order IS 
  'Automatically assigns order to nearest available driver';

COMMENT ON FUNCTION driver_accept_order IS 
  'Driver accepts an assigned order';

COMMENT ON FUNCTION driver_reject_order IS 
  'Driver rejects order and system automatically reassigns to next driver';

COMMENT ON FUNCTION auto_reject_expired_orders IS 
  'Auto-rejects orders where driver did not respond within 30 seconds';

COMMENT ON FUNCTION repost_order_with_increased_fee IS 
  'Allows merchant to repost rejected order with 500 IQD increased fee';

COMMENT ON FUNCTION admin_verify_user IS 
  'Admin function to manually verify user accounts';

-- =====================================================================================
-- END OF MIGRATION
-- =====================================================================================

-- Success message
DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'HUR DELIVERY DATABASE SCHEMA CREATED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'All tables, functions, triggers, and policies have been created successfully.';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Set up pg_cron or Supabase Edge Function for auto-reject';
  RAISE NOTICE '2. Configure Supabase Realtime for critical tables';
  RAISE NOTICE '3. Test the auto-assignment flow';
  RAISE NOTICE '4. Set up your first admin user';
  RAISE NOTICE '';
  RAISE NOTICE 'Documentation: See comments in this file for detailed information.';
  RAISE NOTICE '========================================';
END $$;

