begin;

-- Add reply_to_message_id to messages for threaded replies/quoting
alter table if exists public.messages
  add column if not exists reply_to_message_id uuid references public.messages(id) on delete set null;

create index if not exists idx_messages_reply_to on public.messages(reply_to_message_id);

-- Update RPC to support replies (and keep order_id)
create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text,
  p_kind text default 'text',
  p_order_id uuid default null,
  p_reply_to uuid default null
) returns uuid
language plpgsql
as $$
declare
  v_message_id uuid;
begin
  insert into public.messages(conversation_id, sender_id, body, kind, order_id, reply_to_message_id)
  values (p_conversation_id, auth.uid(), p_body, coalesce(p_kind,'text'), p_order_id, p_reply_to)
  returning id into v_message_id;
  return v_message_id;
end;
$$;

commit;

