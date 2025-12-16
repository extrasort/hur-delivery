-- =====================================================================================
-- ADMIN SEND NOTIFICATIONS RPC
-- =====================================================================================
-- Allows admins to send notifications to users based on role filtering
-- =====================================================================================

CREATE OR REPLACE FUNCTION public.send_notification(
  p_title TEXT,
  p_message TEXT,
  p_target_role TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role TEXT;
  v_inserted_count INTEGER := 0;
  v_user_record RECORD;
BEGIN
  -- Check if caller is admin
  SELECT role INTO v_user_role
  FROM public.users
  WHERE id = auth.uid();
  
  IF v_user_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can send notifications';
  END IF;
  
  -- Insert notifications for target users
  IF p_target_role IS NULL THEN
    -- Send to all users
    INSERT INTO public.notifications (user_id, title, body, type, data)
    SELECT 
      id,
      p_title,
      p_message,
      'admin_broadcast',
      jsonb_build_object('sent_by', 'admin', 'sent_at', NOW())
    FROM public.users
    WHERE role != 'admin'; -- Don't send to admins
    
    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
  ELSE
    -- Send to specific role
    INSERT INTO public.notifications (user_id, title, body, type, data)
    SELECT 
      id,
      p_title,
      p_message,
      'admin_broadcast',
      jsonb_build_object('sent_by', 'admin', 'sent_at', NOW(), 'target_role', p_target_role)
    FROM public.users
    WHERE role = p_target_role;
    
    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
  END IF;
  
  RETURN v_inserted_count;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.send_notification(TEXT, TEXT, TEXT) TO authenticated, anon;

-- =====================================================================================
-- CREATE NOTIFICATION FUNCTION (for single user)
-- =====================================================================================

CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_type TEXT DEFAULT 'info',
  p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (p_user_id, p_title, p_body, p_type, p_data)
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated, anon;

COMMIT;

