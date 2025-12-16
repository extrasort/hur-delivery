-- =====================================================================================
-- Add Admin Payment Methods to wallet_transactions
-- =====================================================================================
-- This migration adds admin-specific payment methods to the wallet_transactions table
-- =====================================================================================

-- Drop existing constraint
ALTER TABLE wallet_transactions 
  DROP CONSTRAINT IF EXISTS wallet_transactions_payment_method_check;

-- Add new constraint with admin payment methods
ALTER TABLE wallet_transactions
  ADD CONSTRAINT wallet_transactions_payment_method_check 
  CHECK (payment_method IN (
    -- User payment methods
    'zain_cash',
    'qi_card',
    'wayl',
    'hur_representative',
    -- Admin payment methods
    'admin_adjustment',
    'admin_manual',
    'admin_transfer',
    'admin_cash',
    'admin_bank_transfer',
    'admin_pos',
    -- System methods
    'initial_gift'
  ));

-- Add comment
COMMENT ON CONSTRAINT wallet_transactions_payment_method_check ON wallet_transactions IS 
  'Payment method constraint: includes user methods (zain_cash, qi_card, wayl, hur_representative), admin methods (admin_*), and system methods (initial_gift)';

