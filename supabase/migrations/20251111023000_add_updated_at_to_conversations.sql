-- Ensure conversations table exposes an updated_at timestamp for ordering in admin tools

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT timezone('utc', now());

-- Backfill existing rows where updated_at is null (if column existed without default)
UPDATE public.conversations
SET updated_at = timezone('utc', now())
WHERE updated_at IS NULL;

-- Keep updated_at in sync on updates
DROP TRIGGER IF EXISTS set_conversations_updated_at ON public.conversations;
CREATE TRIGGER set_conversations_updated_at
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

