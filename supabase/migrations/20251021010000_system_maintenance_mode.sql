-- =====================================================================================
-- SYSTEM MAINTENANCE/SHUTDOWN MODE
-- =====================================================================================
-- Allows admins to temporarily disable the system for maintenance
-- When disabled:
-- - Drivers cannot go online
-- - Merchants cannot create orders
-- - Active orders continue normally
-- - Users can still explore the app
-- =====================================================================================

-- Add system_enabled setting if it doesn't exist
INSERT INTO system_settings (key, value, value_type, description, is_public)
VALUES (
  'system_enabled',
  'true',
  'boolean',
  'System active status - set to false for maintenance mode',
  TRUE
)
ON CONFLICT (key) DO UPDATE
SET description = 'System active status - set to false for maintenance mode';

-- Function to force all drivers offline (called when system is disabled)
CREATE OR REPLACE FUNCTION force_all_drivers_offline()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  affected_count INTEGER;
BEGIN
  -- Update all online drivers to offline
  UPDATE users
  SET is_online = false
  WHERE role = 'driver' AND is_online = true;
  
  GET DIAGNOSTICS affected_count = ROW_COUNT;
  
  RETURN affected_count;
END;
$$;

-- Function to check if system is enabled
CREATE OR REPLACE FUNCTION is_system_enabled()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  system_status TEXT;
BEGIN
  SELECT value INTO system_status
  FROM system_settings
  WHERE key = 'system_enabled';
  
  RETURN COALESCE(system_status = 'true', true);
END;
$$;

-- Trigger to prevent drivers from going online when system is disabled
CREATE OR REPLACE FUNCTION prevent_online_when_system_disabled()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- If driver is trying to go online
  IF NEW.role = 'driver' AND NEW.is_online = true AND OLD.is_online = false THEN
    -- Check if system is enabled
    IF NOT is_system_enabled() THEN
      RAISE EXCEPTION 'النظام حالياً في وضع الصيانة. لا يمكن الاتصال بالإنترنت.'
        USING HINT = 'SYSTEM_DISABLED';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_prevent_online_when_disabled ON users;
CREATE TRIGGER trigger_prevent_online_when_disabled
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION prevent_online_when_system_disabled();

-- Trigger to prevent order creation when system is disabled
CREATE OR REPLACE FUNCTION prevent_orders_when_system_disabled()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if system is enabled
  IF NOT is_system_enabled() THEN
    RAISE EXCEPTION 'النظام حالياً في وضع الصيانة. لا يمكن إنشاء طلبات جديدة.'
      USING HINT = 'SYSTEM_DISABLED';
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_prevent_orders_when_disabled ON orders;
CREATE TRIGGER trigger_prevent_orders_when_disabled
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION prevent_orders_when_system_disabled();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION force_all_drivers_offline() TO authenticated;
GRANT EXECUTE ON FUNCTION is_system_enabled() TO authenticated;
GRANT EXECUTE ON FUNCTION prevent_online_when_system_disabled() TO authenticated;
GRANT EXECUTE ON FUNCTION prevent_orders_when_system_disabled() TO authenticated;

-- =====================================================================================
-- DONE! System maintenance mode is now ready
-- =====================================================================================

-- To enable maintenance mode (shutdown system):
-- UPDATE system_settings SET value = 'false' WHERE key = 'system_enabled';

-- To disable maintenance mode (restore system):
-- UPDATE system_settings SET value = 'true' WHERE key = 'system_enabled';

-- To check current status:
-- SELECT value FROM system_settings WHERE key = 'system_enabled';

-- To force all drivers offline:
-- SELECT force_all_drivers_offline();

