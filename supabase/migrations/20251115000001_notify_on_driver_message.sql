-- =====================================================================================
-- NOTIFY USER WHEN DRIVER SENDS MESSAGE
-- =====================================================================================
-- This migration modifies send_message to automatically create a notification
-- when a driver sends a message, which triggers the push notification edge function
-- =====================================================================================

begin;

-- Add 'message' to allowed notification types
alter table public.notifications 
drop constraint if exists notifications_type_check;

alter table public.notifications 
add constraint notifications_type_check check (
  type in (
    'order_assigned', 
    'order_accepted', 
    'order_status_update', 
    'order_delivered', 
    'order_cancelled',
    'order_rejected',
    'payment', 
    'system',
    'message'  -- Added for driver messages
  )
);

-- Modify send_message function to notify recipients when driver sends a message
create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text default null,
  p_kind text default 'text',
  p_order_id uuid default null,
  p_reply_to uuid default null,
  p_sender_id uuid default null,
  p_attachment_url text default null,
  p_attachment_type text default null
) returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_message public.messages%rowtype;
  v_sender uuid;
  v_sender_role text;
  v_recipient_id uuid;
  v_sender_name text;
  v_message_preview text;
  v_placeholder_phone text := '9990000001';
begin
  v_sender := coalesce(p_sender_id, auth.uid());
  if v_sender is null then
    raise exception 'UNAUTHENTICATED_SENDER';
  end if;

  -- Ensure sender exists in users table
  insert into public.users(id, name, role, phone, is_online, created_at)
  values (v_sender, 'مستخدم', 'admin', v_placeholder_phone, true, now())
  on conflict (id) do update
    set phone = coalesce(public.users.phone, excluded.phone),
        name  = coalesce(public.users.name, excluded.name),
        role  = coalesce(public.users.role, excluded.role),
        updated_at = now();

  -- Get sender's role and name
  select role, name into v_sender_role, v_sender_name
  from public.users
  where id = v_sender;

  -- Insert the message
  insert into public.messages(
    conversation_id,
    sender_id,
    body,
    kind,
    order_id,
    reply_to_message_id,
    attachment_url,
    attachment_type
  )
  values (
    p_conversation_id,
    v_sender,
    coalesce(p_body, ''),
    coalesce(p_kind, 'text'),
    p_order_id,
    p_reply_to,
    p_attachment_url,
    p_attachment_type
  )
  returning * into v_message;

  -- If sender is a driver, notify the other participants
  if v_sender_role = 'driver' then
    -- Get message preview (first 100 chars or indicate attachment)
    if p_attachment_url is not null then
      v_message_preview := case p_attachment_type
        when 'image' then 'صورة / Image'
        when 'file' then 'ملف / File'
        else 'مرفق / Attachment'
      end;
    else
      v_message_preview := coalesce(substring(p_body from 1 for 100), 'رسالة جديدة / New message');
    end if;

    -- Find all other participants in the conversation (excluding the sender)
    for v_recipient_id in
      select cp.user_id
      from conversation_participants cp
      where cp.conversation_id = p_conversation_id
        and cp.user_id != v_sender
    loop
      -- Create notification for each recipient
      insert into public.notifications(
        user_id,
        type,
        title,
        body,
        data
      )
      values (
        v_recipient_id,
        'message',
        coalesce(v_sender_name, 'سائق / Driver'),
        v_message_preview,
        jsonb_build_object(
          'conversation_id', p_conversation_id::text,
          'message_id', v_message.id::text,
          'sender_id', v_sender::text,
          'sender_name', coalesce(v_sender_name, 'سائق / Driver'),
          'order_id', coalesce(p_order_id::text, '')
        )
      );
    end loop;
  end if;

  return v_message;
end;
$$;

grant execute on function public.send_message(uuid, text, text, uuid, uuid, uuid, text, text) to authenticated;
grant execute on function public.send_message(uuid, text, text, uuid, uuid, uuid, text, text) to anon;

commit;

