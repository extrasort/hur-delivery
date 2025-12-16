-- Create voice-orders storage bucket for merchant voice recordings
-- This bucket stores voice order recordings with proper access control

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'voice-orders',
  'voice-orders',
  false,  -- Not public - access controlled by RLS
  10485760,  -- 10MB limit per file (reasonable for voice recordings)
  ARRAY['audio/aac', 'audio/m4a', 'audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/webm', 'audio/ogg', 'application/octet-stream']
)
ON CONFLICT (id) DO NOTHING;

-- Create voice_recordings table to track metadata
CREATE TABLE IF NOT EXISTS voice_recordings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  merchant_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,  -- Path in storage bucket
  filename TEXT NOT NULL,
  duration_seconds INTEGER,  -- Duration in seconds
  file_size_bytes BIGINT,  -- File size in bytes
  transcription TEXT,  -- Cached transcription
  extracted_data JSONB,  -- Cached extracted order data
  notes TEXT,  -- User notes about this recording
  is_archived BOOLEAN DEFAULT FALSE,  -- Soft delete
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_used_at TIMESTAMPTZ  -- Track when last used for an order
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_voice_recordings_merchant_id ON voice_recordings(merchant_id);
CREATE INDEX IF NOT EXISTS idx_voice_recordings_created_at ON voice_recordings(merchant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voice_recordings_not_archived ON voice_recordings(merchant_id, is_archived) WHERE is_archived = FALSE;

-- Add RLS policies for voice_recordings table
ALTER TABLE voice_recordings ENABLE ROW LEVEL SECURITY;

-- Merchants can view their own recordings
CREATE POLICY "Merchants can view own recordings"
  ON voice_recordings
  FOR SELECT
  USING (auth.uid() = merchant_id);

-- Merchants can insert their own recordings
CREATE POLICY "Merchants can insert own recordings"
  ON voice_recordings
  FOR INSERT
  WITH CHECK (auth.uid() = merchant_id);

-- Merchants can update their own recordings
CREATE POLICY "Merchants can update own recordings"
  ON voice_recordings
  FOR UPDATE
  USING (auth.uid() = merchant_id)
  WITH CHECK (auth.uid() = merchant_id);

-- Merchants can delete their own recordings
CREATE POLICY "Merchants can delete own recordings"
  ON voice_recordings
  FOR DELETE
  USING (auth.uid() = merchant_id);

-- Add RLS policies for storage.objects
-- Merchants can upload to their own folder
CREATE POLICY "Merchants can upload voice recordings"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'voice-orders' 
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND auth.role() = 'authenticated'
  );

-- Merchants can view their own recordings
CREATE POLICY "Merchants can view own voice recordings"
  ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'voice-orders' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Merchants can update their own recordings
CREATE POLICY "Merchants can update own voice recordings"
  ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'voice-orders' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Merchants can delete their own recordings
CREATE POLICY "Merchants can delete own voice recordings"
  ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'voice-orders' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_voice_recording_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at on voice_recordings
CREATE TRIGGER trg_voice_recording_updated_at
  BEFORE UPDATE ON voice_recordings
  FOR EACH ROW
  EXECUTE FUNCTION update_voice_recording_updated_at();

-- Function to clean up old archived recordings (older than 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_voice_recordings()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  WITH deleted AS (
    DELETE FROM voice_recordings
    WHERE is_archived = TRUE 
      AND updated_at < NOW() - INTERVAL '30 days'
    RETURNING *
  )
  SELECT COUNT(*) INTO deleted_count FROM deleted;
  
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Comment on table and columns
COMMENT ON TABLE voice_recordings IS 'Stores metadata for merchant voice order recordings';
COMMENT ON COLUMN voice_recordings.storage_path IS 'Path to file in voice-orders bucket';
COMMENT ON COLUMN voice_recordings.transcription IS 'Cached transcription from OpenAI Whisper';
COMMENT ON COLUMN voice_recordings.extracted_data IS 'Cached order data extracted by GPT';
COMMENT ON COLUMN voice_recordings.is_archived IS 'Soft delete flag - archived recordings can be permanently deleted after 30 days';
COMMENT ON COLUMN voice_recordings.last_used_at IS 'Timestamp when recording was last used to create an order';

