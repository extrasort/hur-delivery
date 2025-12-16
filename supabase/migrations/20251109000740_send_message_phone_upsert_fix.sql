begin;

-- Finalize send_message to fix NOT NULL phone by updating existing rows with NULL phone
create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text,
  p_kind text default 'text',
  p_order_id uuid default null,
  p_reply_to uuid default null,
  p_sender_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_message_id uuid;
  v_sender uuid;
  v_placeholder_phone text := '9990000001';
begin
  v_sender := coalesce(p_sender_id, auth.uid());
  if v_sender is null then
    raise exception 'UNAUTHENTICATED_SENDER';
  end if;

  -- Upsert sender with non-null phone; if row exists but phone is NULL, update to placeholder
  insert into public.users(id, name, role, phone, is_online, created_at)
  values (v_sender, 'مستخدم', 'admin', v_placeholder_phone, true, now())
  on conflict (id) do update
    set phone = coalesce(public.users.phone, excluded.phone),
        name  = coalesce(public.users.name, excluded.name),
        role  = coalesce(public.users.role, excluded.role),
        updated_at = now();

  insert into public.messages(conversation_id, sender_id, body, kind, order_id, reply_to_message_id)
  values (p_conversation_id, v_sender, p_body, coalesce(p_kind,'text'), p_order_id, p_reply_to)
  returning id into v_message_id;

  return v_message_id;
end;
$$;

commit;

