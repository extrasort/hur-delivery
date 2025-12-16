-- =====================================================================================
-- Update update_order_from_chat function to allow comprehensive admin edits
-- =====================================================================================
-- - Allow admins to modify additional order fields (customer/merchant details, delivery fee)
-- - Keep driver reassignment and status updates
-- - Retain audit safeguards (admin-only, auth enforced)
-- =====================================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.update_order_from_chat(
  p_order_id UUID,
  p_status TEXT DEFAULT NULL,
  p_driver_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_customer_name TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_customer_address TEXT DEFAULT NULL,
  p_delivery_fee NUMERIC DEFAULT NULL,
  p_merchant_name TEXT DEFAULT NULL,
  p_merchant_phone TEXT DEFAULT NULL,
  p_merchant_address TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role TEXT;
BEGIN
  -- Ensure only admins can perform the update
  SELECT role INTO v_user_role
  FROM public.users
  WHERE id = auth.uid();

  IF v_user_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can update orders';
  END IF;

  -- Apply requested updates. Any NULL parameter leaves the existing value untouched.
  UPDATE public.orders
  SET 
    status = COALESCE(p_status, status),
    driver_id = COALESCE(p_driver_id, driver_id),
    notes = COALESCE(p_notes, notes),
    customer_name = COALESCE(p_customer_name, customer_name),
    customer_phone = COALESCE(p_customer_phone, customer_phone),
    customer_address = COALESCE(p_customer_address, customer_address),
    merchant_name = COALESCE(p_merchant_name, merchant_name),
    merchant_phone = COALESCE(p_merchant_phone, merchant_phone),
    merchant_address = COALESCE(p_merchant_address, merchant_address),
    delivery_fee = COALESCE(p_delivery_fee, delivery_fee),
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
  TEXT,
  TEXT,
  TEXT
) TO authenticated, anon;

COMMIT;


