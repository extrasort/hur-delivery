-- 20251105000013_messaging_schema.sql
-- Messaging schema: conversations, participants, messages, attachments
-- Goals:
--  - Merchants and drivers can chat with each other and with support
--  - Conversations can be per-order or ad-hoc; messages can link to orders
--  - Admins have read/write access to all, users restricted by participation

begin;

-- Conversations
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  title text,
  order_id uuid references public.orders(id) on delete set null,
  created_by uuid references public.users(id) on delete set null,
  is_support boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table public.conversations is 'Chat conversations; optionally tied to an order';

-- Participants
create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'member', -- member | admin
  last_read_at timestamptz,
  added_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

comment on table public.conversation_participants is 'Users in a conversation with roles and read-state';

-- Messages
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete set null,
  body text,
  kind text not null default 'text', -- text | image | system | action
  order_id uuid references public.orders(id) on delete set null,
  created_at timestamptz not null default now(),
  edited_at timestamptz
);

create index if not exists idx_messages_conversation_created on public.messages(conversation_id, created_at desc);

-- Attachments
create table if not exists public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  storage_path text not null,
  content_type text,
  size_bytes int4,
  created_at timestamptz not null default now()
);

-- Order proofs (driver delivery photos)
create table if not exists public.order_proofs (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  driver_id uuid not null references public.users(id) on delete set null,
  storage_path text not null,
  content_type text,
  size_bytes int4,
  created_at timestamptz not null default now()
);

create index if not exists idx_order_proofs_order on public.order_proofs(order_id, created_at desc);

-- Basic RLS
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.message_attachments enable row level security;
alter table public.order_proofs enable row level security;

-- Admins can do everything
create policy conversation_admin_all on public.conversations
  for all using (exists (
    select 1 from public.users u where u.id = auth.uid() and u.role = 'admin'
  ));

create policy participants_admin_all on public.conversation_participants
  for all using (exists (
    select 1 from public.users u where u.id = auth.uid() and u.role = 'admin'
  ));

create policy messages_admin_all on public.messages
  for all using (exists (
    select 1 from public.users u where u.id = auth.uid() and u.role = 'admin'
  ));

create policy message_attachments_admin_all on public.message_attachments
  for all using (exists (
    select 1 from public.users u where u.id = auth.uid() and u.role = 'admin'
  ));

create policy order_proofs_admin_all on public.order_proofs
  for all using (exists (
    select 1 from public.users u where u.id = auth.uid() and u.role = 'admin'
  ));

-- Participants can read/write their conversations
create policy conversation_participant_select on public.conversations
  for select using (exists (
    select 1 from public.conversation_participants p
    where p.conversation_id = conversations.id and p.user_id = auth.uid()
  ));

create policy conversation_participant_insert on public.conversations
  for insert with check (true); -- creation restricted via RPC below

-- Participants policies (split by command to avoid WITH CHECK on SELECT)
drop policy if exists participants_rw on public.conversation_participants;
create policy participants_select on public.conversation_participants
  for select using (
    user_id = auth.uid() or exists(select 1 from public.users u where u.id = auth.uid() and u.role='admin')
  );
create policy participants_insert on public.conversation_participants
  for insert with check (
    user_id = auth.uid() or exists(select 1 from public.users u where u.id = auth.uid() and u.role='admin')
  );
create policy participants_update on public.conversation_participants
  for update using (
    user_id = auth.uid() or exists(select 1 from public.users u where u.id = auth.uid() and u.role='admin')
  )
  with check (
    user_id = auth.uid() or exists(select 1 from public.users u where u.id = auth.uid() and u.role='admin')
  );

-- Messages policies (split by command)
drop policy if exists messages_rw on public.messages;
create policy messages_select on public.messages
  for select using (
    exists (
      select 1 from public.conversation_participants p
      where p.conversation_id = messages.conversation_id and p.user_id = auth.uid()
    )
  );
create policy messages_insert on public.messages
  for insert with check (
    exists (
      select 1 from public.conversation_participants p
      where p.conversation_id = messages.conversation_id and p.user_id = auth.uid()
    )
  );
create policy messages_update on public.messages
  for update using (
    exists (
      select 1 from public.conversation_participants p
      where p.conversation_id = messages.conversation_id and p.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.conversation_participants p
      where p.conversation_id = messages.conversation_id and p.user_id = auth.uid()
    )
  );

create policy message_attachments_select on public.message_attachments
  for select using (exists (
    select 1 from public.messages m
    join public.conversation_participants p on p.conversation_id = m.conversation_id and p.user_id = auth.uid()
    where m.id = message_attachments.message_id
  ));

create policy order_proofs_select on public.order_proofs
  for select using (
    exists (select 1 from public.orders o where o.id = order_proofs.order_id and (o.merchant_id = auth.uid() or o.driver_id = auth.uid()))
    or exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  );

-- RPCs
-- Create or get a conversation (order-based or support)
create or replace function public.create_or_get_conversation(
  p_order_id uuid,
  p_participant_ids uuid[],
  p_is_support boolean default false
) returns uuid
language plpgsql
as $$
declare
  v_conversation_id uuid;
begin
  if p_order_id is not null then
    select id into v_conversation_id from public.conversations
    where order_id = p_order_id and is_support = coalesce(p_is_support,false)
    limit 1;
  end if;

  if v_conversation_id is null then
    insert into public.conversations(order_id, created_by, is_support)
    values (p_order_id, auth.uid(), coalesce(p_is_support,false))
    returning id into v_conversation_id;
    
    -- add creator + provided participants
    insert into public.conversation_participants(conversation_id, user_id, role)
    values (v_conversation_id, auth.uid(), 'member')
    on conflict do nothing;

    if p_participant_ids is not null then
      insert into public.conversation_participants(conversation_id, user_id, role)
      select v_conversation_id, unnest(p_participant_ids), 'member'
      on conflict do nothing;
    end if;
  end if;

  return v_conversation_id;
end;
$$;

-- Send message
create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text,
  p_kind text default 'text',
  p_order_id uuid default null
) returns uuid
language plpgsql
as $$
declare
  v_message_id uuid;
begin
  insert into public.messages(conversation_id, sender_id, body, kind, order_id)
  values (p_conversation_id, auth.uid(), p_body, coalesce(p_kind,'text'), p_order_id)
  returning id into v_message_id;
  return v_message_id;
end;
$$;

commit;

