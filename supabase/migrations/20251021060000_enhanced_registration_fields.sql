-- =====================================================================================
-- ENHANCED REGISTRATION FIELDS
-- =====================================================================================
-- 1. Add document type for users (driver license, passport, national ID)
-- 2. Add business type for merchants
-- =====================================================================================

-- Add document_type column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS document_type TEXT DEFAULT 'national_id';

-- Add constraint for valid document types
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_document_type_check;
ALTER TABLE users ADD CONSTRAINT users_document_type_check 
CHECK (document_type IN ('national_id', 'driver_license', 'passport'));

-- Add business_type column for merchants
ALTER TABLE users ADD COLUMN IF NOT EXISTS business_type TEXT;

-- Add constraint for valid business types
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_business_type_check;
ALTER TABLE users ADD CONSTRAINT users_business_type_check 
CHECK (
    role != 'merchant' OR 
    business_type IN ('restaurant', 'grocery', 'pharmacy', 'electronics', 'clothing', 'bakery', 'cafe', 'supermarket', 'other')
);

-- Add RLS policy to allow users to update their own document_type and business_type
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'users' 
    AND policyname = 'Users can update their own document_type and business_type'
  ) THEN
    CREATE POLICY "Users can update their own document_type and business_type"
    ON users
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);
  END IF;
END $$;

-- Add comments
COMMENT ON COLUMN users.document_type IS 'Type of identification document uploaded (national_id, driver_license, passport)';
COMMENT ON COLUMN users.business_type IS 'Type of business for merchants (restaurant, grocery, pharmacy, etc.)';

-- =====================================================================================
-- DONE! Enhanced registration fields are ready
-- =====================================================================================

