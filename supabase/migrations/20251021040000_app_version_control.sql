-- =====================================================================================
-- APP VERSION CONTROL
-- =====================================================================================
-- Allows admins to set minimum required app version
-- Users with older versions will be forced to update
-- =====================================================================================

-- Add app version to system_settings
INSERT INTO system_settings (key, value, description)
VALUES 
  ('min_app_version', '1.0.0', 'Minimum required app version (semantic versioning: major.minor.patch)')
ON CONFLICT (key) DO NOTHING;

-- Add RLS policy for reading app version (public access)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'system_settings' 
    AND policyname = 'Allow public read of min_app_version'
  ) THEN
    CREATE POLICY "Allow public read of min_app_version"
    ON system_settings
    FOR SELECT
    USING (key = 'min_app_version');
  END IF;
END $$;

-- Grant public access to read system_settings
GRANT SELECT ON system_settings TO anon, authenticated;

COMMENT ON COLUMN system_settings.key IS 'Setting key (e.g., support_phone, min_app_version)';
COMMENT ON COLUMN system_settings.value IS 'Setting value';

-- =====================================================================================
-- DONE! App version control is ready
-- =====================================================================================

