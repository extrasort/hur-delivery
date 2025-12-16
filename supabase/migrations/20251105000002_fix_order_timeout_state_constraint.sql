-- =====================================================================================
-- FIX: Ensure order_timeout_state table has proper constraint for ON CONFLICT
-- =====================================================================================
-- This migration ensures the order_timeout_state table has the proper primary key
-- constraint that allows ON CONFLICT to work in triggers
-- =====================================================================================

-- First, check if the table exists and has the correct structure
DO $$
BEGIN
  -- Check if table exists
  IF NOT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'order_timeout_state'
  ) THEN
    -- Create the table if it doesn't exist
    CREATE TABLE order_timeout_state (
      order_id UUID PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
      driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      assigned_at TIMESTAMPTZ NOT NULL,
      timeout_seconds INTEGER NOT NULL DEFAULT 30,
      remaining_seconds INTEGER NOT NULL,
      expired BOOLEAN NOT NULL DEFAULT FALSE,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    
    RAISE NOTICE '✅ Created order_timeout_state table';
  ELSE
    -- Table exists, ensure it has the primary key constraint
    -- Check if order_id is the primary key
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
      WHERE tc.constraint_type = 'PRIMARY KEY'
        AND tc.table_name = 'order_timeout_state'
        AND kcu.column_name = 'order_id'
    ) THEN
      -- Add primary key constraint if it doesn't exist
      ALTER TABLE order_timeout_state
      ADD CONSTRAINT order_timeout_state_pkey PRIMARY KEY (order_id);
      
      RAISE NOTICE '✅ Added PRIMARY KEY constraint to order_timeout_state.order_id';
    ELSE
      RAISE NOTICE '✅ order_timeout_state.order_id already has PRIMARY KEY constraint';
    END IF;
  END IF;
  
  -- Ensure indexes exist
  CREATE INDEX IF NOT EXISTS idx_order_timeout_driver ON order_timeout_state(driver_id);
  CREATE INDEX IF NOT EXISTS idx_order_timeout_expired ON order_timeout_state(expired) WHERE NOT expired;
  
  RAISE NOTICE '✅ Indexes verified/created';
END $$;

-- Verify the constraint exists
DO $$
DECLARE
  v_has_pk BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_name = 'order_timeout_state'
      AND kcu.column_name = 'order_id'
  ) INTO v_has_pk;
  
  IF NOT v_has_pk THEN
    RAISE EXCEPTION '❌ Failed to create PRIMARY KEY constraint on order_timeout_state.order_id';
  ELSE
    RAISE NOTICE '✅ Verified: order_timeout_state.order_id has PRIMARY KEY constraint';
  END IF;
END $$;

-- =====================================================================================
-- FIX: Update trigger to handle edge cases
-- =====================================================================================

-- Recreate the trigger function to be more defensive
CREATE OR REPLACE FUNCTION trigger_update_timeout_state()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_elapsed INTEGER;
  v_remaining INTEGER;
  v_table_exists BOOLEAN;
  v_constraint_exists BOOLEAN;
BEGIN
  -- Check if order_timeout_state table exists
  SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'order_timeout_state'
  ) INTO v_table_exists;
  
  -- If table doesn't exist, skip
  IF NOT v_table_exists THEN
    RETURN NEW;
  END IF;
  
  -- Check if PRIMARY KEY constraint exists on order_id
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_name = 'order_timeout_state'
      AND kcu.column_name = 'order_id'
  ) INTO v_constraint_exists;
  
  -- Only process if order is pending with an assigned driver
  IF NEW.status = 'pending' AND NEW.driver_id IS NOT NULL AND NEW.driver_assigned_at IS NOT NULL THEN
    -- Calculate elapsed and remaining time
    v_elapsed := EXTRACT(EPOCH FROM (NOW() - NEW.driver_assigned_at))::INTEGER;
    v_remaining := GREATEST(0, 30 - v_elapsed);
    
    -- Use different approach based on whether constraint exists
    IF v_constraint_exists THEN
      -- Upsert using ON CONFLICT (requires PRIMARY KEY)
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
        driver_id = EXCLUDED.driver_id,
        assigned_at = EXCLUDED.assigned_at,
        remaining_seconds = EXCLUDED.remaining_seconds,
        expired = EXCLUDED.expired,
        updated_at = NOW();
    ELSE
      -- Fallback: DELETE then INSERT (no constraint needed)
      DELETE FROM order_timeout_state WHERE order_id = NEW.id;
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
      );
    END IF;
  
  -- When order is no longer pending or driver removed, delete timeout state
  ELSIF (NEW.status != 'pending' OR NEW.driver_id IS NULL) THEN
    DELETE FROM order_timeout_state WHERE order_id = NEW.id;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Error in trigger_update_timeout_state for order %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- Recreate the trigger
DROP TRIGGER IF EXISTS trg_update_timeout_state ON orders;
CREATE TRIGGER trg_update_timeout_state
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_timeout_state();

-- =====================================================================================
-- FIX: Update update_order_timeout_states() function to handle missing constraints
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
  v_constraint_exists BOOLEAN;
BEGIN
  -- Check if PRIMARY KEY constraint exists on order_id
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_name = 'order_timeout_state'
      AND kcu.column_name = 'order_id'
  ) INTO v_constraint_exists;
  
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
    
    -- Use different approach based on whether constraint exists
    IF v_constraint_exists THEN
      -- Upsert using ON CONFLICT (requires PRIMARY KEY)
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
        remaining_seconds = EXCLUDED.remaining_seconds,
        expired = EXCLUDED.expired,
        updated_at = NOW();
    ELSE
      -- Fallback: DELETE then INSERT (no constraint needed)
      DELETE FROM order_timeout_state WHERE order_id = v_order.id;
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
      );
    END IF;
    
    v_updated := v_updated + 1;
  END LOOP;
  
  -- Delete entries for orders that are no longer pending with driver
  DELETE FROM order_timeout_state
  WHERE order_id NOT IN (
    SELECT id FROM orders 
    WHERE status = 'pending' AND driver_id IS NOT NULL
  );
  
  RETURN v_updated;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail
    RAISE WARNING 'Error in update_order_timeout_states: %', SQLERRM;
    RETURN 0;
END;
$$;

-- =====================================================================================
-- VERIFY
-- =====================================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Order Timeout State Constraint Fix Applied!';
  RAISE NOTICE '';
  RAISE NOTICE 'Both trigger and update function now handle missing constraints gracefully';
  RAISE NOTICE '';
END $$;

