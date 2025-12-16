-- =====================================================================================
-- SYSTEM ANNOUNCEMENTS
-- =====================================================================================
-- Allows admins to create screen-wide notifications for maintenance, events, updates, etc.
-- These announcements appear when users access their dashboards.
-- =====================================================================================

-- Create announcements table
CREATE TABLE IF NOT EXISTS system_announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Content
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('maintenance', 'event', 'update', 'info', 'warning', 'success')),
  
  -- Visibility settings
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_dismissable BOOLEAN NOT NULL DEFAULT true,
  target_roles TEXT[] NOT NULL DEFAULT ARRAY['merchant', 'driver', 'admin'], -- Which roles can see it
  
  -- Timing
  start_time TIMESTAMPTZ DEFAULT NOW(),
  end_time TIMESTAMPTZ, -- NULL means indefinite
  
  -- Tracking
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create dismissals tracking table (to know which users dismissed which announcements)
CREATE TABLE IF NOT EXISTS announcement_dismissals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID REFERENCES system_announcements(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  dismissed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Prevent duplicate dismissals
  UNIQUE(announcement_id, user_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_announcements_active ON system_announcements(is_active, start_time, end_time) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_announcements_roles ON system_announcements USING GIN(target_roles);
CREATE INDEX IF NOT EXISTS idx_dismissals_user ON announcement_dismissals(user_id);
CREATE INDEX IF NOT EXISTS idx_dismissals_announcement ON announcement_dismissals(announcement_id);

-- Enable RLS
ALTER TABLE system_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcement_dismissals ENABLE ROW LEVEL SECURITY;

-- RLS Policies for announcements
-- Everyone can view active announcements for their role
CREATE POLICY "Users can view active announcements for their role"
  ON system_announcements
  FOR SELECT
  USING (
    is_active = true 
    AND (start_time IS NULL OR start_time <= NOW())
    AND (end_time IS NULL OR end_time > NOW())
    AND (
      target_roles @> ARRAY[auth.jwt() -> 'user_metadata' ->> 'role']
      OR auth.jwt() -> 'user_metadata' ->> 'role' = 'admin'
    )
  );

-- Only admins can insert/update/delete announcements
CREATE POLICY "Admins can manage announcements"
  ON system_announcements
  FOR ALL
  USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin');

-- RLS Policies for dismissals
-- Users can view their own dismissals
CREATE POLICY "Users can view own dismissals"
  ON announcement_dismissals
  FOR SELECT
  USING (user_id = auth.uid());

-- Users can insert their own dismissals
CREATE POLICY "Users can dismiss announcements"
  ON announcement_dismissals
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Admins can view all dismissals
CREATE POLICY "Admins can view all dismissals"
  ON announcement_dismissals
  FOR SELECT
  USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin');

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_announcement_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-updating updated_at
CREATE TRIGGER trigger_update_announcement_timestamp
  BEFORE UPDATE ON system_announcements
  FOR EACH ROW
  EXECUTE FUNCTION update_announcement_updated_at();

-- Create a view for active announcements (easier querying)
CREATE OR REPLACE VIEW active_announcements AS
SELECT 
  a.*,
  u.name as created_by_name,
  (
    SELECT COUNT(*)
    FROM announcement_dismissals d
    WHERE d.announcement_id = a.id
  ) as dismissal_count
FROM system_announcements a
LEFT JOIN users u ON a.created_by = u.id
WHERE 
  a.is_active = true
  AND (a.start_time IS NULL OR a.start_time <= NOW())
  AND (a.end_time IS NULL OR a.end_time > NOW())
ORDER BY a.created_at DESC;

-- Grant permissions
GRANT SELECT ON active_announcements TO authenticated;

-- Insert a sample announcement (optional - remove if not needed)
INSERT INTO system_announcements (
  title,
  message,
  type,
  is_dismissable,
  target_roles,
  created_by
) VALUES (
  'مرحباً بك في حر للتوصيل',
  'نظام التوصيل السريع الجديد الآن جاهز للاستخدام. يمكنك البدء بإنشاء الطلبات الآن.',
  'success',
  true,
  ARRAY['merchant', 'driver'],
  NULL
);

