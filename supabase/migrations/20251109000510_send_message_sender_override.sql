begin;

-- Allow optional explicit sender id for admin web (fallback if auth context is missing)
create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text,
  p_kind text default 'text',
  p_order_id uuid default null,
  p_reply_to uuid default null,
  p_sender_id uuid default null
) returns uuid
language plpgsql
as $$
declare
  v_message_id uuid;
  v_sender uuid;
begin
  v_sender := coalesce(p_sender_id, auth.uid());
  if v_sender is null then
    raise exception 'UNAUTHENTICATED_SENDER';
  end if;

  insert into public.messages(conversation_id, sender_id, body, kind, order_id, reply_to_message_id)
  values (p_conversation_id, v_sender, p_body, coalesce(p_kind,'text'), p_order_id, p_reply_to)
  returning id into v_message_id;
  return v_message_id;
end;
$$;

commit;

