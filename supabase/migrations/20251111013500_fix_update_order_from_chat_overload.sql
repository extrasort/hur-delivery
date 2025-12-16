-- =====================================================================================
-- Resolve update_order_from_chat overload ambiguity
-- =====================================================================================
-- Drops the legacy 4-argument function signature and reinstalls the extended
-- admin-only function with full editing capabilities.
-- =====================================================================================

BEGIN;

-- Remove legacy function definition that only accepted status/driver/notes.
DROP FUNCTION IF EXISTS public.update_order_from_chat(
  UUID,
  TEXT,
  UUID,
  TEXT   
);

-- Drop any existing extended signature before recreating to avoid duplicates.
DROP FUNCTION IF EXISTS public.update_order_from_chat(
  UUID,
  TEXT,
  UUID,
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  NUMERIC,
  TEXT,
  TEXT,
  TEXT
);
DROP FUNCTION IF EXISTS public.update_order_from_chat(
  UUID,
  TEXT,
  UUID,
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  NUMERIC,
  NUMERIC,
  NUMERIC,
  TEXT,
  NUMERIC,
  NUMERIC,
  NUMERIC,
  TEXT,
  TEXT,
  TEXT,
  UUID,
  BOOLEAN,
  TIMESTAMPTZ,
  INT,
  BOOLEAN,
  BOOLEAN,
  BOOLEAN
);

-- Recreate the extended admin function.
CREATE OR REPLACE FUNCTION public.update_order_from_chat(
  p_order_id UUID,
  p_status TEXT DEFAULT NULL,
  p_driver_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_customer_name TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_pickup_address TEXT DEFAULT NULL,
  p_pickup_latitude NUMERIC DEFAULT NULL,
  p_pickup_longitude NUMERIC DEFAULT NULL,
  p_delivery_address TEXT DEFAULT NULL,
  p_delivery_latitude NUMERIC DEFAULT NULL,
  p_delivery_longitude NUMERIC DEFAULT NULL,
  p_delivery_fee NUMERIC DEFAULT NULL,
  p_total_amount NUMERIC DEFAULT NULL,
  p_original_delivery_fee NUMERIC DEFAULT NULL,
  p_repost_count INT DEFAULT NULL,
  p_cancellation_reason TEXT DEFAULT NULL,
  p_rejection_reason TEXT DEFAULT NULL,
  p_vehicle_type TEXT DEFAULT NULL,
  p_bulk_order_id UUID DEFAULT NULL,
  p_is_bulk_order BOOLEAN DEFAULT NULL,
  p_ready_at TIMESTAMPTZ DEFAULT NULL,
  p_ready_countdown INT DEFAULT NULL,
  p_customer_location_provided BOOLEAN DEFAULT NULL,
  p_driver_notified_location BOOLEAN DEFAULT NULL,
  p_coordinates_auto_updated BOOLEAN DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role TEXT;
BEGIN
  SELECT role INTO v_user_role
  FROM public.users
  WHERE id = auth.uid();

  IF v_user_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can update orders';
  END IF;

  UPDATE public.orders
  SET 
    status = COALESCE(p_status, status),
    driver_id = COALESCE(p_driver_id, driver_id),
    notes = COALESCE(p_notes, notes),
    customer_name = COALESCE(p_customer_name, customer_name),
    customer_phone = COALESCE(p_customer_phone, customer_phone),
    pickup_address = COALESCE(p_pickup_address, pickup_address),
    pickup_latitude = COALESCE(p_pickup_latitude, pickup_latitude),
    pickup_longitude = COALESCE(p_pickup_longitude, pickup_longitude),
    pickup_location = CASE
      WHEN p_pickup_latitude IS NOT NULL AND p_pickup_longitude IS NOT NULL
        THEN ST_SetSRID(ST_MakePoint(p_pickup_longitude, p_pickup_latitude), 4326)::geography
      ELSE pickup_location
    END,
    delivery_address = COALESCE(p_delivery_address, delivery_address),
    delivery_latitude = COALESCE(p_delivery_latitude, delivery_latitude),
    delivery_longitude = COALESCE(p_delivery_longitude, delivery_longitude),
    delivery_location = CASE
      WHEN p_delivery_latitude IS NOT NULL AND p_delivery_longitude IS NOT NULL
        THEN ST_SetSRID(ST_MakePoint(p_delivery_longitude, p_delivery_latitude), 4326)::geography
      ELSE delivery_location
    END,
    delivery_fee = COALESCE(p_delivery_fee, delivery_fee),
    total_amount = COALESCE(p_total_amount, total_amount),
    original_delivery_fee = COALESCE(p_original_delivery_fee, original_delivery_fee),
    repost_count = COALESCE(p_repost_count, repost_count),
    cancellation_reason = COALESCE(p_cancellation_reason, cancellation_reason),
    rejection_reason = COALESCE(p_rejection_reason, rejection_reason),
    vehicle_type = COALESCE(p_vehicle_type, vehicle_type),
    bulk_order_id = COALESCE(p_bulk_order_id, bulk_order_id),
    is_bulk_order = COALESCE(p_is_bulk_order, is_bulk_order),
    ready_at = COALESCE(p_ready_at, ready_at),
    ready_countdown = COALESCE(p_ready_countdown, ready_countdown),
    customer_location_provided = COALESCE(p_customer_location_provided, customer_location_provided),
    driver_notified_location = COALESCE(p_driver_notified_location, driver_notified_location),
    coordinates_auto_updated = COALESCE(p_coordinates_auto_updated, coordinates_auto_updated),
    updated_at = NOW()
  WHERE id = p_order_id;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_order_from_chat(
  UUID,
  TEXT,
  UUID,
  TEXT,
  TEXT,
  TEXT,
  TEXT,
  NUMERIC,
  NUMERIC,
  NUMERIC,
  TEXT,
  NUMERIC,
  NUMERIC,
  NUMERIC,
  TEXT,
  TEXT,
  TEXT,
  UUID,
  BOOLEAN,
  TIMESTAMPTZ,
  INT,
  BOOLEAN,
  BOOLEAN,
  BOOLEAN
) TO authenticated, anon;

COMMIT;


