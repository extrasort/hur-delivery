-- =====================================================================================
-- FIX REFRESH TOKEN AND EMAIL CONSTRAINT ISSUES
-- =====================================================================================
-- This migration addresses two issues:
-- 1. Refresh token errors when tokens are missing/revoked
-- 2. Email constraint violations when updating users via admin API
-- =====================================================================================

begin;

-- =====================================================================================
-- PART 1: SAFE USER EMAIL UPDATE FUNCTION
-- =====================================================================================
-- This function safely updates a user's email in auth.users without violating
-- the users_email_partial_key constraint
-- =====================================================================================

CREATE OR REPLACE FUNCTION safe_update_auth_user_email(
  p_user_id UUID,
  p_new_email TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public
AS $$
DECLARE
  v_current_email TEXT;
  v_email_exists BOOLEAN;
  v_result JSONB;
BEGIN
  -- Get current email
  SELECT email INTO v_current_email
  FROM auth.users
  WHERE id = p_user_id;
  
  IF v_current_email IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;
  
  -- If email is the same, no update needed
  IF v_current_email = p_new_email THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Email unchanged',
      'email', p_new_email
    );
  END IF;
  
  -- Check if new email already exists (excluding current user)
  SELECT EXISTS(
    SELECT 1
    FROM auth.users
    WHERE email = p_new_email
      AND id != p_user_id
      AND email IS NOT NULL
  ) INTO v_email_exists;
  
  IF v_email_exists THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Email already exists',
      'email', p_new_email
    );
  END IF;
  
  -- Update email (this will be done via Admin API, not directly in SQL)
  -- This function just validates before the update
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Email can be updated',
    'current_email', v_current_email,
    'new_email', p_new_email
  );
END;
$$;

GRANT EXECUTE ON FUNCTION safe_update_auth_user_email(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION safe_update_auth_user_email(UUID, TEXT) TO service_role;

COMMENT ON FUNCTION safe_update_auth_user_email IS 'Safely validates email updates to prevent constraint violations';

-- =====================================================================================
-- PART 2: HELPER FUNCTION TO CHECK FOR DUPLICATE EMAILS
-- =====================================================================================

CREATE OR REPLACE FUNCTION check_email_available(
  p_email TEXT,
  p_exclude_user_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = auth, public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  IF p_email IS NULL OR p_email = '' THEN
    RETURN true; -- NULL/empty emails are allowed
  END IF;
  
  SELECT EXISTS(
    SELECT 1
    FROM auth.users
    WHERE email = p_email
      AND (p_exclude_user_id IS NULL OR id != p_exclude_user_id)
      AND email IS NOT NULL
  ) INTO v_exists;
  
  RETURN NOT v_exists;
END;
$$;

GRANT EXECUTE ON FUNCTION check_email_available(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_email_available(TEXT, UUID) TO service_role;

COMMENT ON FUNCTION check_email_available IS 'Checks if an email is available for use';

-- =====================================================================================
-- PART 3: REFRESH TOKEN MANAGEMENT (INFORMATIONAL)
-- =====================================================================================
-- Note: Supabase manages refresh tokens automatically
-- The auth.refresh_tokens table is in the auth schema which has restricted access
-- Token cleanup and expiration are handled automatically by Supabase
-- =====================================================================================

commit;

-- =====================================================================================
-- NOTES FOR DEVELOPERS
-- =====================================================================================
-- 
-- REFRESH TOKEN ERRORS:
-- When you see "Refresh Token Not Found" errors:
-- 1. The client should handle this gracefully by signing the user out
-- 2. The user will need to sign in again
-- 3. This is normal behavior when:
--    - A new login revokes old tokens
--    - Tokens expire and are cleaned up
--    - User logs in from another device
--
-- EMAIL CONSTRAINT VIOLATIONS:
-- When updating users via Admin API:
-- 1. Always check if the email exists before updating
-- 2. Use safe_update_auth_user_email() to validate before updating
-- 3. Or use check_email_available() to check availability
-- 4. Never update to an email that already exists for another user
--
-- =====================================================================================

