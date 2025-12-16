-- =====================================================================================
-- DEVICE SESSION MANAGEMENT
-- =====================================================================================
-- Ensures only one device per user account
-- Automatically logs out other devices when a new login occurs
-- =====================================================================================

-- =====================================================================================
-- 1. CREATE DEVICE SESSIONS TABLE
-- =====================================================================================

CREATE TABLE IF NOT EXISTS device_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  device_info JSONB,
  is_active BOOLEAN DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  logged_out_at TIMESTAMPTZ,
  UNIQUE(user_id, device_id)
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_device_sessions_user ON device_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_device_sessions_active ON device_sessions(user_id, is_active) WHERE is_active = TRUE;

-- =====================================================================================
-- 2. FUNCTION: Register Device Session
-- =====================================================================================

CREATE OR REPLACE FUNCTION register_device_session(
  p_user_id UUID,
  p_device_id TEXT,
  p_device_info JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_other_sessions INTEGER;
  v_session_id UUID;
BEGIN
  -- Count other active sessions for this user
  SELECT COUNT(*) INTO v_other_sessions
  FROM device_sessions
  WHERE user_id = p_user_id
    AND device_id != p_device_id
    AND is_active = TRUE;
  
  -- Deactivate ALL other sessions for this user (logout other devices)
  UPDATE device_sessions
  SET 
    is_active = FALSE,
    logged_out_at = NOW()
  WHERE user_id = p_user_id
    AND device_id != p_device_id
    AND is_active = TRUE;
  
  -- Insert or update this device's session
  WITH inserted_session AS (
    INSERT INTO device_sessions (
      user_id,
      device_id,
      device_info,
      is_active,
      last_seen_at
    )
    VALUES (
      p_user_id,
      p_device_id,
      p_device_info,
      TRUE,
      NOW()
    )
    ON CONFLICT (user_id, device_id) 
    DO UPDATE SET
      is_active = TRUE,
      last_seen_at = NOW(),
      device_info = COALESCE(EXCLUDED.device_info, device_sessions.device_info)
    RETURNING id
  )
  SELECT id INTO v_session_id FROM inserted_session;
  
  -- Return info about logout
  RETURN jsonb_build_object(
    'session_id', v_session_id,
    'other_devices_logged_out', v_other_sessions,
    'message', CASE 
      WHEN v_other_sessions > 0 THEN 
        format('Logged out %s other device(s)', v_other_sessions)
      ELSE 
        'Session registered'
    END
  );
END;
$$;

-- =====================================================================================
-- 3. FUNCTION: Update Session Heartbeat
-- =====================================================================================

CREATE OR REPLACE FUNCTION update_session_heartbeat(
  p_user_id UUID,
  p_device_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE device_sessions
  SET last_seen_at = NOW()
  WHERE user_id = p_user_id
    AND device_id = p_device_id
    AND is_active = TRUE;
  
  RETURN FOUND;
END;
$$;

-- =====================================================================================
-- 4. FUNCTION: Check If Session is Active
-- =====================================================================================

CREATE OR REPLACE FUNCTION check_session_active(
  p_user_id UUID,
  p_device_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_active BOOLEAN;
BEGIN
  SELECT is_active INTO v_is_active
  FROM device_sessions
  WHERE user_id = p_user_id
    AND device_id = p_device_id;
  
  RETURN COALESCE(v_is_active, FALSE);
END;
$$;

-- =====================================================================================
-- 5. FUNCTION: Logout Device
-- =====================================================================================

CREATE OR REPLACE FUNCTION logout_device_session(
  p_user_id UUID,
  p_device_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE device_sessions
  SET 
    is_active = FALSE,
    logged_out_at = NOW()
  WHERE user_id = p_user_id
    AND device_id = p_device_id;
  
  RETURN FOUND;
END;
$$;

-- =====================================================================================
-- 6. RLS POLICIES
-- =====================================================================================

ALTER TABLE device_sessions ENABLE ROW LEVEL SECURITY;

-- Users can view their own sessions
CREATE POLICY "sessions_select_own" ON device_sessions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- System can manage sessions
CREATE POLICY "sessions_service_all" ON device_sessions
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- Functions can insert/update
CREATE POLICY "sessions_functions" ON device_sessions
  FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

-- =====================================================================================
-- 7. ENABLE REALTIME FOR SESSION MONITORING
-- =====================================================================================

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE device_sessions;
  RAISE NOTICE '✅ Realtime enabled for device_sessions';
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE '✅ Realtime already enabled for device_sessions';
  WHEN OTHERS THEN 
    RAISE NOTICE '⚠️  Could not enable realtime for device_sessions: %', SQLERRM;
END $$;

-- =====================================================================================
-- SUCCESS MESSAGE
-- =====================================================================================

DO $$ 
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DEVICE SESSION MANAGEMENT INSTALLED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Features:';
  RAISE NOTICE '  ✅ Only one device per account';
  RAISE NOTICE '  ✅ Auto-logout other devices';
  RAISE NOTICE '  ✅ Session heartbeat monitoring';
  RAISE NOTICE '  ✅ Real-time session updates';
  RAISE NOTICE '';
  RAISE NOTICE 'When user logs in on new device:';
  RAISE NOTICE '  → Old device gets logged out automatically';
  RAISE NOTICE '  → User sees "Logged in from another device"';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

