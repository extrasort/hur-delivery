-- Merchant Wallet System
-- This migration creates the wallet system for merchants including:
-- 1. Merchant wallets table
-- 2. Wallet transactions table
-- 3. Functions to handle wallet operations
-- 4. Triggers to deduct fees from wallet on order delivery

-- Create merchant_wallets table
CREATE TABLE IF NOT EXISTS merchant_wallets (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  merchant_id uuid UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  balance decimal(10,2) DEFAULT 10000.00, -- Starting balance of 10,000 IQD as gift
  order_fee decimal(10,2) DEFAULT 500.00, -- Fee per order (adjustable per merchant)
  credit_limit decimal(10,2) DEFAULT -10000.00, -- Minimum balance before requiring top-up
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create wallet_transactions table
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  merchant_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  transaction_type text NOT NULL CHECK (transaction_type IN ('top_up', 'order_fee', 'refund', 'adjustment', 'initial_gift')),
  amount decimal(10,2) NOT NULL, -- Positive for credits, negative for debits
  balance_before decimal(10,2) NOT NULL,
  balance_after decimal(10,2) NOT NULL,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  payment_method text CHECK (payment_method IN ('zain_cash', 'qi_card', 'hur_representative', 'admin_adjustment', 'initial_gift')),
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_merchant_wallets_merchant ON merchant_wallets(merchant_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_merchant ON wallet_transactions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created ON wallet_transactions(created_at DESC);

-- Enable RLS
ALTER TABLE merchant_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for merchant_wallets
CREATE POLICY "Merchants can view their own wallet" ON merchant_wallets
  FOR SELECT USING (merchant_id = auth.uid());

CREATE POLICY "System can create wallets" ON merchant_wallets
  FOR INSERT WITH CHECK (true);

CREATE POLICY "System can update wallets" ON merchant_wallets
  FOR UPDATE USING (true);

-- RLS Policies for wallet_transactions
CREATE POLICY "Merchants can view their own transactions" ON wallet_transactions
  FOR SELECT USING (merchant_id = auth.uid());

CREATE POLICY "System can create transactions" ON wallet_transactions
  FOR INSERT WITH CHECK (true);

-- Function to initialize wallet for new merchant
CREATE OR REPLACE FUNCTION initialize_merchant_wallet()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create wallet for merchants
  IF NEW.role = 'merchant' THEN
    INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
    VALUES (NEW.id, 10000.00, 500.00, -10000.00);
    
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
      10000.00,
      0.00,
      10000.00,
      'initial_gift',
      'هدية ترحيبية من حر'
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create wallet when merchant registers
DROP TRIGGER IF EXISTS create_merchant_wallet_trigger ON users;
CREATE TRIGGER create_merchant_wallet_trigger
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION initialize_merchant_wallet();

-- Function to deduct order fee from merchant wallet
CREATE OR REPLACE FUNCTION deduct_order_fee_from_wallet()
RETURNS TRIGGER AS $$
DECLARE
  v_wallet_id uuid;
  v_current_balance decimal(10,2);
  v_order_fee decimal(10,2);
  v_credit_limit decimal(10,2);
  v_new_balance decimal(10,2);
BEGIN
  -- Only deduct fee when order is delivered
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    
    -- Get merchant wallet info
    SELECT id, balance, order_fee, credit_limit 
    INTO v_wallet_id, v_current_balance, v_order_fee, v_credit_limit
    FROM merchant_wallets
    WHERE merchant_id = NEW.merchant_id;
    
    -- If wallet doesn't exist, create it (shouldn't happen, but safety check)
    IF v_wallet_id IS NULL THEN
      INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
      VALUES (NEW.merchant_id, 10000.00, 500.00, -10000.00)
      RETURNING id, balance, order_fee, credit_limit 
      INTO v_wallet_id, v_current_balance, v_order_fee, v_credit_limit;
    END IF;
    
    -- Calculate new balance
    v_new_balance := v_current_balance - v_order_fee;
    
    -- Update wallet balance
    UPDATE merchant_wallets
    SET balance = v_new_balance,
        updated_at = now()
    WHERE id = v_wallet_id;
    
    -- Record transaction
    INSERT INTO wallet_transactions (
      merchant_id,
      transaction_type,
      amount,
      balance_before,
      balance_after,
      order_id,
      notes
    ) VALUES (
      NEW.merchant_id,
      'order_fee',
      -v_order_fee,
      v_current_balance,
      v_new_balance,
      NEW.id,
      'رسوم توصيل طلب #' || substring(NEW.id::text, 1, 8)
    );
    
    -- Log if balance goes below credit limit (for monitoring)
    IF v_new_balance < v_credit_limit THEN
      RAISE NOTICE 'Merchant % balance (%) is below credit limit (%)', 
        NEW.merchant_id, v_new_balance, v_credit_limit;
    END IF;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to deduct fee when order is delivered
DROP TRIGGER IF EXISTS deduct_order_fee_trigger ON orders;
CREATE TRIGGER deduct_order_fee_trigger
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION deduct_order_fee_from_wallet();

-- Function to add balance to wallet (top-up)
CREATE OR REPLACE FUNCTION add_wallet_balance(
  p_merchant_id uuid,
  p_amount decimal,
  p_payment_method text,
  p_notes text DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_current_balance decimal(10,2);
  v_new_balance decimal(10,2);
  v_transaction_id uuid;
BEGIN
  -- Get current balance
  SELECT balance INTO v_current_balance
  FROM merchant_wallets
  WHERE merchant_id = p_merchant_id;
  
  -- If wallet doesn't exist, create it
  IF v_current_balance IS NULL THEN
    INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
    VALUES (p_merchant_id, 10000.00, 500.00, -10000.00)
    RETURNING balance INTO v_current_balance;
  END IF;
  
  -- Calculate new balance
  v_new_balance := v_current_balance + p_amount;
  
  -- Update wallet balance
  UPDATE merchant_wallets
  SET balance = v_new_balance,
      updated_at = now()
  WHERE merchant_id = p_merchant_id;
  
  -- Record transaction
  INSERT INTO wallet_transactions (
    merchant_id,
    transaction_type,
    amount,
    balance_before,
    balance_after,
    payment_method,
    notes
  ) VALUES (
    p_merchant_id,
    'top_up',
    p_amount,
    v_current_balance,
    v_new_balance,
    p_payment_method,
    COALESCE(p_notes, 'شحن المحفظة')
  ) RETURNING id INTO v_transaction_id;
  
  -- Return result
  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'balance_before', v_current_balance,
    'balance_after', v_new_balance,
    'amount', p_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if merchant can place order (balance above limit)
CREATE OR REPLACE FUNCTION can_merchant_place_order(p_merchant_id uuid)
RETURNS boolean AS $$
DECLARE
  v_balance decimal(10,2);
  v_credit_limit decimal(10,2);
BEGIN
  SELECT balance, credit_limit 
  INTO v_balance, v_credit_limit
  FROM merchant_wallets
  WHERE merchant_id = p_merchant_id;
  
  -- If no wallet exists, create it and return true
  IF v_balance IS NULL THEN
    INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
    VALUES (p_merchant_id, 10000.00, 500.00, -10000.00);
    RETURN true;
  END IF;
  
  -- Check if balance is above credit limit
  RETURN v_balance >= v_credit_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get wallet summary for merchant
CREATE OR REPLACE FUNCTION get_wallet_summary(p_merchant_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_wallet_info jsonb;
  v_total_spent decimal(10,2);
  v_total_topped_up decimal(10,2);
  v_total_orders integer;
BEGIN
  -- Get wallet info
  SELECT jsonb_build_object(
    'balance', balance,
    'order_fee', order_fee,
    'credit_limit', credit_limit,
    'can_place_order', balance >= credit_limit,
    'created_at', created_at
  ) INTO v_wallet_info
  FROM merchant_wallets
  WHERE merchant_id = p_merchant_id;
  
  -- Get total spent on orders
  SELECT COALESCE(SUM(ABS(amount)), 0) INTO v_total_spent
  FROM wallet_transactions
  WHERE merchant_id = p_merchant_id 
    AND transaction_type = 'order_fee';
  
  -- Get total topped up
  SELECT COALESCE(SUM(amount), 0) INTO v_total_topped_up
  FROM wallet_transactions
  WHERE merchant_id = p_merchant_id 
    AND transaction_type = 'top_up';
  
  -- Get total orders
  SELECT COUNT(*) INTO v_total_orders
  FROM orders
  WHERE merchant_id = p_merchant_id 
    AND status = 'delivered';
  
  -- Return combined data
  RETURN v_wallet_info || jsonb_build_object(
    'total_spent', v_total_spent,
    'total_topped_up', v_total_topped_up,
    'total_orders', v_total_orders
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update trigger for wallet updated_at
CREATE TRIGGER update_merchant_wallets_updated_at 
  BEFORE UPDATE ON merchant_wallets
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT ALL ON merchant_wallets TO anon, authenticated;
GRANT ALL ON wallet_transactions TO anon, authenticated;
GRANT EXECUTE ON FUNCTION initialize_merchant_wallet() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION deduct_order_fee_from_wallet() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION add_wallet_balance(uuid, decimal, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION can_merchant_place_order(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_wallet_summary(uuid) TO anon, authenticated;

-- Initialize wallets for existing merchants
INSERT INTO merchant_wallets (merchant_id, balance, order_fee, credit_limit)
SELECT id, 10000.00, 500.00, -10000.00
FROM users
WHERE role = 'merchant' 
  AND id NOT IN (SELECT merchant_id FROM merchant_wallets)
ON CONFLICT (merchant_id) DO NOTHING;

-- Record initial gift transactions for existing merchants who just got wallets
INSERT INTO wallet_transactions (
  merchant_id,
  transaction_type,
  amount,
  balance_before,
  balance_after,
  payment_method,
  notes
)
SELECT 
  merchant_id,
  'initial_gift',
  10000.00,
  0.00,
  10000.00,
  'initial_gift',
  'هدية ترحيبية من حر'
FROM merchant_wallets
WHERE merchant_id NOT IN (
  SELECT merchant_id FROM wallet_transactions WHERE transaction_type = 'initial_gift'
);

-- Enable real-time for wallet tables
ALTER PUBLICATION supabase_realtime ADD TABLE merchant_wallets;
ALTER PUBLICATION supabase_realtime ADD TABLE wallet_transactions;

-- Add comment for documentation
COMMENT ON TABLE merchant_wallets IS 'Stores merchant wallet balances and settings';
COMMENT ON TABLE wallet_transactions IS 'Records all wallet transactions for merchants';
COMMENT ON FUNCTION add_wallet_balance IS 'Adds balance to merchant wallet and records transaction';
COMMENT ON FUNCTION can_merchant_place_order IS 'Checks if merchant has sufficient balance to place orders';
COMMENT ON FUNCTION get_wallet_summary IS 'Returns comprehensive wallet summary for merchant';
