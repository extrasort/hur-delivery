-- =====================================================================================
-- REMOVE ID NUMBER FORMAT CONSTRAINT
-- =====================================================================================
-- This migration removes the users_id_number_format constraint that requires
-- id_number to be exactly 12 digits. This constraint is causing errors when
-- inserting/updating users with id_number values that don't match the format.
-- =====================================================================================

begin;

-- Drop the constraint if it exists
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_id_number_format;

-- Update the comment to reflect that the format is no longer enforced
COMMENT ON COLUMN users.id_number IS 'National ID number - must be unique (format no longer enforced)';

commit;

-- =====================================================================================
-- NOTES
-- =====================================================================================
-- The constraint users_id_number_format required id_number to be exactly 12 digits
-- if it was not NULL. This has been removed to allow more flexibility.
-- 
-- The unique index on id_number (idx_users_id_number_unique) is still in place
-- to prevent duplicate ID numbers.
-- =====================================================================================

