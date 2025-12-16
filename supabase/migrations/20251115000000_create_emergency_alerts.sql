-- =====================================================================================
-- EMERGENCY ALERTS TABLE
-- =====================================================================================
-- Creates the emergency_alerts table for tracking emergency alerts from users
-- This table stores emergency alerts sent by users (drivers, merchants, customers)
-- =====================================================================================

-- Create emergency_alerts table
CREATE TABLE IF NOT EXISTS emergency_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- User who sent the alert
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  
  -- Location information (if available)
  location_lat NUMERIC(10, 8),
  location_lng NUMERIC(11, 8),
  
  -- Alert message/content
  message TEXT,
  
  -- Status
  resolved BOOLEAN NOT NULL DEFAULT false,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_user_id ON emergency_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_resolved ON emergency_alerts(resolved);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_created_at ON emergency_alerts(created_at DESC);

-- Enable Row Level Security
ALTER TABLE emergency_alerts ENABLE ROW LEVEL SECURITY;

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_emergency_alerts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_emergency_alerts_updated_at
  BEFORE UPDATE ON emergency_alerts
  FOR EACH ROW
  EXECUTE FUNCTION update_emergency_alerts_updated_at();

-- Grant permissions
GRANT ALL ON emergency_alerts TO authenticated;
GRANT ALL ON emergency_alerts TO anon;

-- Note: RLS policies should be created separately using ADMIN_RLS_SETUP.sql
-- or ADD_EMERGENCY_ALERTS_RLS.sql after this migration runs

