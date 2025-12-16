-- =====================================================================================
-- MAKE MERCHANT WELCOME GIFT CONFIGURABLE
-- =====================================================================================
-- Adds merchant_welcome_gift to system_settings
-- Updates initialize_merchant_wallet() to read from settings
-- =====================================================================================

-- Add merchant_welcome_gift setting
INSERT INTO system_settings (key, value, value_type, description, is_public)
VALUES (
  'merchant_welcome_gift',
  '10000',
  'number',
  'Welcome gift amount for new merchants (IQD)',
  FALSE
)
ON CONFLICT (key) DO NOTHING;

-- Update the wallet initialization function to use settings
CREATE OR REPLACE FUNCTION initialize_merchant_wallet()
RETURNS TRIGGER AS $$
DECLARE
  welcome_gift DECIMAL(10,2) := 10000.00; -- Default
  setting_value TEXT;
BEGIN
  -- Only create wallet for merchants
  IF NEW.role = 'merchant' THEN
    -- Get welcome gift from settings
    SELECT value INTO setting_value
    FROM system_settings
    WHERE key = 'merchant_welcome_gift';
    
    -- Use setting if found, otherwise use default
    IF setting_value IS NOT NULL THEN
      welcome_gift := setting_value::DECIMAL;
    END IF;
    
    -- Create wallet with configurable welcome gift
    INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
    VALUES (NEW.id, welcome_gift, 500.00, -welcome_gift);
    
    -- Record the initial gift transaction
    INSERT INTO wallet_transactions (
      merchant_id,
      transaction_type,
      amount,
      balance_before,
      balance_after,
      payment_method,
      notes
    ) VALUES (
      NEW.id,
      'initial_gift',
      welcome_gift,
      0.00,
      welcome_gift,
      'initial_gift',
      'هدية ترحيبية من حر - Gift: ' || welcome_gift || ' IQD'
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permission to the updated function
GRANT EXECUTE ON FUNCTION initialize_merchant_wallet() TO anon, authenticated;

COMMENT ON FUNCTION initialize_merchant_wallet() IS 'Creates wallet for new merchants with configurable welcome gift from system_settings';

