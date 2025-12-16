-- =====================================================================================
-- ORDER TIMEOUT STATE TABLE
-- Stores the current timeout state for each pending order with assigned driver
-- =====================================================================================

-- Create table to track timeout state
CREATE TABLE IF NOT EXISTS order_timeout_state (
  order_id UUID PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL,
  timeout_seconds INTEGER NOT NULL DEFAULT 30,
  remaining_seconds INTEGER NOT NULL,
  expired BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_order_timeout_driver ON order_timeout_state(driver_id);
CREATE INDEX IF NOT EXISTS idx_order_timeout_expired ON order_timeout_state(expired) WHERE NOT expired;

-- Enable RLS
ALTER TABLE order_timeout_state ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Drivers can view their timeout states" ON order_timeout_state;
CREATE POLICY "Drivers can view their timeout states" ON order_timeout_state
  FOR SELECT USING (auth.uid() = driver_id);

DROP POLICY IF EXISTS "Merchants can view timeout states for their orders" ON order_timeout_state;
CREATE POLICY "Merchants can view timeout states for their orders" ON order_timeout_state
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_timeout_state.order_id 
        AND orders.merchant_id = auth.uid()
    )
  );

-- =====================================================================================
-- FUNCTION: Update Order Timeout States
-- Calculates remaining time for all active pending orders
-- =====================================================================================

CREATE OR REPLACE FUNCTION update_order_timeout_states()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_elapsed INTEGER;
  v_remaining INTEGER;
  v_updated INTEGER := 0;
BEGIN
  -- Loop through all pending orders with assigned drivers
  FOR v_order IN
    SELECT id, driver_id, driver_assigned_at
    FROM orders
    WHERE status = 'pending'
      AND driver_id IS NOT NULL
      AND driver_assigned_at IS NOT NULL
  LOOP
    -- Calculate elapsed and remaining time
    v_elapsed := EXTRACT(EPOCH FROM (NOW() - v_order.driver_assigned_at))::INTEGER;
    v_remaining := GREATEST(0, 30 - v_elapsed);
    
    -- Upsert into timeout state table
    INSERT INTO order_timeout_state (
      order_id,
      driver_id,
      assigned_at,
      remaining_seconds,
      expired,
      updated_at
    ) VALUES (
      v_order.id,
      v_order.driver_id,
      v_order.driver_assigned_at,
      v_remaining,
      (v_remaining = 0),
      NOW()
    )
    ON CONFLICT (order_id) DO UPDATE SET
      remaining_seconds = v_remaining,
      expired = (v_remaining = 0),
      updated_at = NOW();
    
    v_updated := v_updated + 1;
  END LOOP;
  
  -- Delete entries for orders that are no longer pending with driver
  DELETE FROM order_timeout_state
  WHERE order_id NOT IN (
    SELECT id FROM orders 
    WHERE status = 'pending' AND driver_id IS NOT NULL
  );
  
  RETURN v_updated;
END;
$$;

-- =====================================================================================
-- TRIGGER: Auto-update timeout state when order changes
-- =====================================================================================

CREATE OR REPLACE FUNCTION trigger_update_timeout_state()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_elapsed INTEGER;
  v_remaining INTEGER;
BEGIN
  -- When order becomes pending with driver, create/update timeout state
  IF NEW.status = 'pending' AND NEW.driver_id IS NOT NULL AND NEW.driver_assigned_at IS NOT NULL THEN
    v_elapsed := EXTRACT(EPOCH FROM (NOW() - NEW.driver_assigned_at))::INTEGER;
    v_remaining := GREATEST(0, 30 - v_elapsed);
    
    INSERT INTO order_timeout_state (
      order_id,
      driver_id,
      assigned_at,
      remaining_seconds,
      expired,
      updated_at
    ) VALUES (
      NEW.id,
      NEW.driver_id,
      NEW.driver_assigned_at,
      v_remaining,
      (v_remaining = 0),
      NOW()
    )
    ON CONFLICT (order_id) DO UPDATE SET
      driver_id = NEW.driver_id,
      assigned_at = NEW.driver_assigned_at,
      remaining_seconds = v_remaining,
      expired = (v_remaining = 0),
      updated_at = NOW();
  
  -- When order is no longer pending or driver removed, delete timeout state
  ELSIF (NEW.status != 'pending' OR NEW.driver_id IS NULL) THEN
    DELETE FROM order_timeout_state WHERE order_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_timeout_state ON orders;
CREATE TRIGGER trg_update_timeout_state
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_timeout_state();

-- =====================================================================================
-- FUNCTION: Continuous timeout state updater (call every 1-2 seconds)
-- =====================================================================================

CREATE OR REPLACE FUNCTION refresh_timeout_states()
RETURNS TABLE (
  order_id UUID,
  remaining_seconds INTEGER,
  expired BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update all timeout states
  PERFORM update_order_timeout_states();
  
  -- Return current states
  RETURN QUERY
  SELECT 
    ots.order_id,
    ots.remaining_seconds,
    ots.expired
  FROM order_timeout_state ots
  ORDER BY ots.remaining_seconds ASC;
END;
$$;

-- =====================================================================================
-- INITIAL POPULATION
-- =====================================================================================

-- Populate timeout states for existing pending orders
SELECT update_order_timeout_states();

-- =====================================================================================
-- COMMENTS
-- =====================================================================================

COMMENT ON TABLE order_timeout_state IS 
  'Stores real-time timeout countdown state for pending orders with assigned drivers';

COMMENT ON FUNCTION update_order_timeout_states IS 
  'Updates timeout remaining seconds for all pending orders. Call every 1-2 seconds.';

COMMENT ON FUNCTION refresh_timeout_states IS 
  'Refreshes and returns all timeout states. Use for real-time subscriptions.';

-- =====================================================================================
-- SUCCESS
-- =====================================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Order Timeout State Table Created!';
  RAISE NOTICE '';
  RAISE NOTICE 'Table: order_timeout_state';
  RAISE NOTICE 'Function: update_order_timeout_states() - Call every 1-2 seconds';
  RAISE NOTICE 'Function: refresh_timeout_states() - Returns current states';
  RAISE NOTICE '';
  RAISE NOTICE 'Frontend should:';
  RAISE NOTICE '1. Subscribe to: order_timeout_state table (real-time)';
  RAISE NOTICE '2. Display: remaining_seconds value directly';
  RAISE NOTICE '3. No calculation needed - just display the value!';
  RAISE NOTICE '';
END $$;

