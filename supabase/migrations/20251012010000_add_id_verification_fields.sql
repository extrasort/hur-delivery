-- Add ID verification fields to users table
-- This migration adds columns for storing ID card information and verification status

-- Add ID number column (12 digits)
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_number VARCHAR(12);

-- Add legal name columns (as it appears on ID)
ALTER TABLE users ADD COLUMN IF NOT EXISTS legal_first_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS legal_father_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS legal_grandfather_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS legal_family_name TEXT;

-- Add ID verification metadata
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_front_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_back_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS selfie_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_expiry_date DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_birth_date DATE;

-- Add verification timestamps
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_verified_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS id_verification_notes TEXT;

-- Add verification status if it doesn't exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'pending';

-- Create unique index on id_number to prevent duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_id_number_unique 
  ON users(id_number) 
  WHERE id_number IS NOT NULL;

-- Create index for verification lookups
CREATE INDEX IF NOT EXISTS idx_users_verification_status 
  ON users(verification_status, id_verified_at);

-- Add constraint to ensure ID number is exactly 12 digits
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_id_number_format'
  ) THEN
    ALTER TABLE users ADD CONSTRAINT users_id_number_format 
      CHECK (id_number IS NULL OR (id_number ~ '^[0-9]{12}$'));
  END IF;
END $$;

-- Function to validate ID number uniqueness
CREATE OR REPLACE FUNCTION check_id_number_unique(p_id_number TEXT, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  existing_user_id UUID;
BEGIN
  -- Check if ID number exists for a different user
  SELECT id INTO existing_user_id
  FROM users
  WHERE id_number = p_id_number
    AND id <> p_user_id
  LIMIT 1;
  
  RETURN existing_user_id IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to update user ID verification
CREATE OR REPLACE FUNCTION update_user_id_verification(
  p_user_id UUID,
  p_id_number TEXT,
  p_legal_first_name TEXT,
  p_legal_father_name TEXT,
  p_legal_grandfather_name TEXT,
  p_legal_family_name TEXT,
  p_id_front_url TEXT,
  p_id_back_url TEXT,
  p_selfie_url TEXT,
  p_id_expiry_date DATE DEFAULT NULL,
  p_id_birth_date DATE DEFAULT NULL,
  p_verification_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  -- No format validation - accept any ID number format
  -- Check if ID number is already used by another user
  IF NOT check_id_number_unique(p_id_number, p_user_id) THEN
    RAISE EXCEPTION 'هذا الرقم الوطني مسجل بالفعل في النظام';
  END IF;
  
  -- Update user record
  UPDATE users
  SET 
    id_number = p_id_number,
    legal_first_name = p_legal_first_name,
    legal_father_name = p_legal_father_name,
    legal_grandfather_name = p_legal_grandfather_name,
    legal_family_name = p_legal_family_name,
    id_front_url = p_id_front_url,
    id_back_url = p_id_back_url,
    selfie_url = p_selfie_url,
    id_expiry_date = p_id_expiry_date,
    id_birth_date = p_id_birth_date,
    id_verified_at = NOW(),
    id_verification_notes = p_verification_notes,
    verification_status = 'approved',
    updated_at = NOW()
  WHERE id = p_user_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_id_number_unique(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_id_verification(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, DATE, TEXT) TO authenticated;

-- Add comments
COMMENT ON COLUMN users.id_number IS 'National ID number - exactly 12 digits, must be unique';
COMMENT ON COLUMN users.legal_first_name IS 'First name as it appears on national ID (الاسم)';
COMMENT ON COLUMN users.legal_father_name IS 'Father name as it appears on national ID (الاب)';
COMMENT ON COLUMN users.legal_grandfather_name IS 'Grandfather name as it appears on national ID (الجد)';
COMMENT ON COLUMN users.legal_family_name IS 'Family name as it appears on national ID (اللقب)';
COMMENT ON COLUMN users.id_front_url IS 'URL to front of national ID card image in storage';
COMMENT ON COLUMN users.id_back_url IS 'URL to back of national ID card image in storage';
COMMENT ON COLUMN users.selfie_url IS 'URL to selfie with ID card image in storage';
COMMENT ON COLUMN users.id_expiry_date IS 'Expiry date of national ID card';
COMMENT ON COLUMN users.id_birth_date IS 'Birth date from national ID card';
COMMENT ON COLUMN users.id_verified_at IS 'Timestamp when ID verification was completed';
COMMENT ON COLUMN users.id_verification_notes IS 'Notes from automated or manual ID verification';

