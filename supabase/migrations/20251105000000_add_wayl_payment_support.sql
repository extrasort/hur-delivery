-- Add Wayl Payment Support
-- This migration adds support for tracking pending Wayl payment links

-- Create pending_topups table to track Wayl payment links
CREATE TABLE IF NOT EXISTS pending_topups (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  merchant_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount decimal(10,2) NOT NULL,
  wayl_reference_id text UNIQUE NOT NULL, -- Unique reference ID for Wayl
  wayl_link_id text, -- Wayl payment link ID
  wayl_link_url text, -- Payment URL to redirect customer
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
  payment_method text DEFAULT 'wayl',
  notes text,
  webhook_data jsonb, -- Store webhook payload for debugging
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz,
  updated_at timestamptz DEFAULT now()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_pending_topups_merchant ON pending_topups(merchant_id);
CREATE INDEX IF NOT EXISTS idx_pending_topups_status ON pending_topups(status);
CREATE INDEX IF NOT EXISTS idx_pending_topups_reference ON pending_topups(wayl_reference_id);
CREATE INDEX IF NOT EXISTS idx_pending_topups_created ON pending_topups(created_at DESC);

-- Enable RLS
ALTER TABLE pending_topups ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Merchants can view their own pending topups" ON pending_topups
  FOR SELECT USING (merchant_id = auth.uid());

CREATE POLICY "System can create pending topups" ON pending_topups
  FOR INSERT WITH CHECK (true);

CREATE POLICY "System can update pending topups" ON pending_topups
  FOR UPDATE USING (true);

-- Update payment_method check in wallet_transactions to include 'wayl'
ALTER TABLE wallet_transactions 
  DROP CONSTRAINT IF EXISTS wallet_transactions_payment_method_check;

ALTER TABLE wallet_transactions
  ADD CONSTRAINT wallet_transactions_payment_method_check 
  CHECK (payment_method IN ('zain_cash', 'qi_card', 'hur_representative', 'admin_adjustment', 'initial_gift', 'wayl'));

-- Function to complete pending topup and add balance
CREATE OR REPLACE FUNCTION complete_wayl_topup(
  p_wayl_reference_id text,
  p_webhook_data jsonb DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_pending_topup pending_topups%ROWTYPE;
  v_result jsonb;
BEGIN
  -- Get pending topup by reference ID
  SELECT * INTO v_pending_topup
  FROM pending_topups
  WHERE wayl_reference_id = p_wayl_reference_id
    AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Pending topup not found or already processed'
    );
  END IF;
  
  -- Update pending topup status
  UPDATE pending_topups
  SET status = 'completed',
      completed_at = now(),
      webhook_data = COALESCE(p_webhook_data, webhook_data),
      updated_at = now()
  WHERE id = v_pending_topup.id;
  
  -- Add balance to wallet using existing function
  SELECT add_wallet_balance(
    v_pending_topup.merchant_id,
    v_pending_topup.amount,
    'wayl',
    'شحن عبر Wayl - ' || v_pending_topup.wayl_reference_id
  ) INTO v_result;
  
  -- Return success
  RETURN jsonb_build_object(
    'success', true,
    'pending_topup_id', v_pending_topup.id,
    'wallet_result', v_result
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION complete_wayl_topup IS 'Completes a pending Wayl topup and adds balance to merchant wallet';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION complete_wayl_topup(text, jsonb) TO authenticated, anon;

