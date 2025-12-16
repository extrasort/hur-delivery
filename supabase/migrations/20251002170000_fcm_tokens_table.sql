              -- Create FCM tokens table for push notifications
-- Enterprise-grade notification system like Uber/Doordash

-- Create user_fcm_tokens table
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    device_id TEXT,
    app_version TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON user_fcm_tokens(fcm_token);

-- Enable RLS
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own FCM tokens" ON user_fcm_tokens
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own FCM tokens" ON user_fcm_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own FCM tokens" ON user_fcm_tokens
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own FCM tokens" ON user_fcm_tokens
    FOR DELETE USING (auth.uid() = user_id);

-- Service role can manage all tokens (for Edge Functions)
CREATE POLICY "Service role can manage all FCM tokens" ON user_fcm_tokens
    FOR ALL USING (auth.role() = 'service_role');

-- Update function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for updated_at
CREATE TRIGGER update_user_fcm_tokens_updated_at 
    BEFORE UPDATE ON user_fcm_tokens 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add FCM message ID to notifications table
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS fcm_message_id TEXT;

-- Create index for FCM message ID
CREATE INDEX IF NOT EXISTS idx_notifications_fcm_message_id ON notifications(fcm_message_id);

-- Grant permissions
GRANT ALL ON user_fcm_tokens TO authenticated;
GRANT ALL ON user_fcm_tokens TO service_role;

-- Comments
COMMENT ON TABLE user_fcm_tokens IS 'Stores FCM tokens for push notifications';
COMMENT ON COLUMN user_fcm_tokens.fcm_token IS 'Firebase Cloud Messaging token';
COMMENT ON COLUMN user_fcm_tokens.platform IS 'Platform: android or ios';
COMMENT ON COLUMN user_fcm_tokens.device_id IS 'Device identifier';
COMMENT ON COLUMN user_fcm_tokens.app_version IS 'App version when token was registered';

-- Success message
DO $$ 
BEGIN
    RAISE NOTICE '✅ FCM tokens table created successfully';
    RAISE NOTICE '✅ RLS policies configured';
    RAISE NOTICE '✅ Indexes created';
    RAISE NOTICE '✅ Ready for enterprise push notifications';
END $$;
