begin;

alter table public.messages
  add column if not exists attachment_url text,
  add column if not exists attachment_type text;

drop function if exists public.send_message(uuid, text, text, uuid, uuid, uuid);
drop function if exists public.send_message(uuid, text, text, uuid, uuid, uuid, text, text);

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'files_conversations_insert'
  ) then
    create policy "files_conversations_insert" on storage.objects
    for insert to authenticated
    with check (
      bucket_id = 'files'
      and name like 'conversations/%'
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'files_conversations_select'
  ) then
    create policy "files_conversations_select" on storage.objects
    for select to authenticated
    using (
      bucket_id = 'files'
      and name like 'conversations/%'
    );
  end if;
end $$;

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
  v_placeholder_phone text := '9990000001';
begin
  v_sender := coalesce(p_sender_id, auth.uid());
  if v_sender is null then
    raise exception 'UNAUTHENTICATED_SENDER';
  end if;

  insert into public.users(id, name, role, phone, is_online, created_at)
  values (v_sender, 'مستخدم', 'admin', v_placeholder_phone, true, now())
  on conflict (id) do update
    set phone = coalesce(public.users.phone, excluded.phone),
        name  = coalesce(public.users.name, excluded.name),
        role  = coalesce(public.users.role, excluded.role),
        updated_at = now();

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

  return v_message;
end;
$$;

grant execute on function public.send_message(uuid, text, text, uuid, uuid, uuid, text, text) to authenticated;
grant execute on function public.send_message(uuid, text, text, uuid, uuid, uuid, text, text) to anon;

commit;
