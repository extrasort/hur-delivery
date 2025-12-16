-- =====================================================================================
-- ADD REFERRAL SOURCE TRACKING
-- =====================================================================================
-- Track how users heard about Hur Delivery for marketing analytics
-- =====================================================================================

-- Add referral_source column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_source TEXT;

-- Add comment
COMMENT ON COLUMN users.referral_source IS 'How the user heard about Hur (e.g., social media, friend, representative, etc.)';

-- Create an index for analytics
CREATE INDEX IF NOT EXISTS idx_users_referral_source ON users(referral_source) WHERE referral_source IS NOT NULL;

-- =====================================================================================
-- DONE! Referral source tracking is now ready
-- =====================================================================================

-- Example referral sources:
-- - 'social_media' - Social Media (فيسبوك، انستغرام، تيك توك)
-- - 'friend' - Friend or Acquaintance (صديق أو معارف)
-- - 'representative' - Hur Representative (ممثل حر)
-- - 'advertisement' - Advertisement (إعلان)
-- - 'search_engine' - Search Engine (محرك بحث)
-- - 'word_of_mouth' - Word of Mouth (من شخص آخر)
-- - 'other' - Other (أخرى)

