-- =====================================================================================
-- CONVERSATION ENHANCEMENTS
-- =====================================================================================
-- 1. Add archived status to conversations
-- 2. Ensure single conversation per user-pair
-- 3. Add RPC to archive conversations
-- 4. Add RPC to update order status from chat
-- =====================================================================================

BEGIN;

-- Add archived column to conversations
ALTER TABLE public.conversations 
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;

-- Add index for archived conversations
CREATE INDEX IF NOT EXISTS idx_conversations_archived 
ON public.conversations(is_archived, created_at DESC);

-- =====================================================================================
-- FUNCTION: Archive Conversation
-- =====================================================================================
CREATE OR REPLACE FUNCTION public.archive_conversation(p_conversation_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role TEXT;
BEGIN
  -- Check if user is admin
  SELECT role INTO v_user_role
  FROM public.users
  WHERE id = auth.uid();
  
  IF v_user_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can archive conversations';
  END IF;
  
  -- Archive the conversation
  UPDATE public.conversations
  SET is_archived = TRUE,
      updated_at = NOW()
  WHERE id = p_conversation_id;
  
  RETURN TRUE;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.archive_conversation(UUID) TO authenticated, anon;

-- =====================================================================================
-- FUNCTION: Unarchive Conversation
-- =====================================================================================
CREATE OR REPLACE FUNCTION public.unarchive_conversation(p_conversation_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role TEXT;
BEGIN
  -- Check if user is admin
  SELECT role INTO v_user_role
  FROM public.users
  WHERE id = auth.uid();
  
  IF v_user_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can unarchive conversations';
  END IF;
  
  -- Unarchive the conversation
  UPDATE public.conversations
  SET is_archived = FALSE,
      updated_at = NOW()
  WHERE id = p_conversation_id;
  
  RETURN TRUE;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.unarchive_conversation(UUID) TO authenticated, anon;

-- =====================================================================================
-- FUNCTION: Update Order from Chat
-- =====================================================================================
CREATE OR REPLACE FUNCTION public.update_order_from_chat(
  p_order_id UUID,
  p_status TEXT DEFAULT NULL,
  p_driver_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role TEXT;
  v_current_status TEXT;
BEGIN
  -- Check if user is admin
  SELECT role INTO v_user_role
  FROM public.users
  WHERE id = auth.uid();
  
  IF v_user_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can update orders';
  END IF;
  
  -- Get current order status
  SELECT status INTO v_current_status
  FROM public.orders
  WHERE id = p_order_id;
  
  -- Don't allow editing delivered/cancelled orders
  IF v_current_status IN ('delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Cannot edit completed or cancelled orders';
  END IF;
  
  -- Update order
  UPDATE public.orders
  SET 
    status = COALESCE(p_status, status),
    driver_id = COALESCE(p_driver_id, driver_id),
    notes = COALESCE(p_notes, notes),
    updated_at = NOW()
  WHERE id = p_order_id;
  
  RETURN TRUE;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.update_order_from_chat(UUID, TEXT, UUID, TEXT) TO authenticated, anon;

-- =====================================================================================
-- FUNCTION: Get or Create Single Conversation Between Users
-- =====================================================================================
CREATE OR REPLACE FUNCTION public.get_or_create_user_conversation(
  p_user_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id UUID;
  v_admin_id UUID;
BEGIN
  -- Get admin user (the one calling this function)
  v_admin_id := auth.uid();
  
  -- Check if conversation already exists between these two users
  SELECT c.id INTO v_conversation_id
  FROM public.conversations c
  INNER JOIN public.conversation_participants cp1 ON cp1.conversation_id = c.id AND cp1.user_id = v_admin_id
  INNER JOIN public.conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id = p_user_id
  WHERE c.is_support = TRUE
    AND c.is_archived = FALSE
  ORDER BY c.created_at DESC
  LIMIT 1;
  
  -- If no conversation exists, create one
  IF v_conversation_id IS NULL THEN
    INSERT INTO public.conversations (created_by, is_support, is_archived)
    VALUES (v_admin_id, TRUE, FALSE)
    RETURNING id INTO v_conversation_id;
    
    -- Add both participants
    INSERT INTO public.conversation_participants (conversation_id, user_id, role)
    VALUES 
      (v_conversation_id, v_admin_id, 'member'),
      (v_conversation_id, p_user_id, 'member')
    ON CONFLICT DO NOTHING;
  END IF;
  
  RETURN v_conversation_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_or_create_user_conversation(UUID) TO authenticated, anon;

COMMIT;

