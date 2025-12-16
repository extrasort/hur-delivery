begin;

-- Remove legacy overloads that cause PostgREST 300 Multiple Choices
DROP FUNCTION IF EXISTS public.send_message(uuid, text, text, uuid);
DROP FUNCTION IF EXISTS public.send_message(uuid, text, text, uuid, uuid);

-- Recreate canonical version with optional sender parameter
CREATE OR REPLACE FUNCTION public.send_message(
  p_conversation_id uuid,
  p_body text,
  p_kind text DEFAULT 'text',
  p_order_id uuid DEFAULT NULL,
  p_reply_to uuid DEFAULT NULL,
  p_sender_id uuid DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_message_id uuid;
  v_sender uuid;
  v_placeholder_phone text := '9990000001';
BEGIN
  v_sender := COALESCE(p_sender_id, auth.uid());
  IF v_sender IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED_SENDER';
  END IF;

  INSERT INTO public.users(id, name, role, phone, is_online, created_at)
  VALUES (v_sender, 'مستخدم', 'admin', v_placeholder_phone, true, NOW())
  ON CONFLICT (id) DO UPDATE
    SET phone = COALESCE(public.users.phone, EXCLUDED.phone),
        name  = COALESCE(public.users.name, EXCLUDED.name),
        role  = COALESCE(public.users.role, EXCLUDED.role),
        updated_at = NOW();

  INSERT INTO public.messages(
    conversation_id,
    sender_id,
    body,
    kind,
    order_id,
    reply_to_message_id
  )
  VALUES (
    p_conversation_id,
    v_sender,
    p_body,
    COALESCE(p_kind, 'text'),
    p_order_id,
    p_reply_to
  )
  RETURNING id INTO v_message_id;

  RETURN v_message_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_message(uuid, text, text, uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_message(uuid, text, text, uuid, uuid, uuid) TO anon;

COMMIT;
