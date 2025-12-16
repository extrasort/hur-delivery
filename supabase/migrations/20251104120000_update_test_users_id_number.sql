-- =====================================================================================
-- UPDATE TEST USERS ID_NUMBER TO LAST 6 DIGITS OF PHONE NUMBER (PADDED TO 12 DIGITS)
-- =====================================================================================
-- This migration updates test users' id_number to match the last 6 digits of their phone number
-- padded to 12 digits (required by the constraint users_id_number_format)
-- This ensures consistency with the phone@idcard password format
-- =====================================================================================

-- Update test users with phone numbers starting with +964999
-- Extract last 6 digits from phone number and pad with leading zeros to 12 digits
UPDATE users
SET id_number = LPAD(RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 6), 12, '0')
WHERE phone LIKE '+964999%'
  AND (id_number IS NULL OR id_number = '');

-- Update the two specific test users (9647814104097 and 9647816820964)
-- Extract last 6 digits and pad to 12 digits
UPDATE users
SET id_number = LPAD(RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 6), 12, '0')
WHERE phone IN ('+9647814104097', '+9647816820964')
  AND (id_number IS NULL OR id_number = '');

-- If you want to force update even if id_number exists, use this instead:
-- UPDATE users
-- SET id_number = LPAD(RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 6), 12, '0')
-- WHERE phone LIKE '+964999%' OR phone IN ('+9647814104097', '+9647816820964');

-- Verify the updates
SELECT 
  phone,
  id_number,
  LPAD(RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 6), 12, '0') as expected_id_number,
  CASE 
    WHEN id_number = LPAD(RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 6), 12, '0') THEN '✅ Match'
    ELSE '❌ Mismatch'
  END as status,
  LENGTH(id_number) as id_number_length
FROM users
WHERE phone LIKE '+964999%' OR phone IN ('+9647814104097', '+9647816820964')
ORDER BY phone;

