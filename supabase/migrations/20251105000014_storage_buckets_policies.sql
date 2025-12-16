-- 20251105000014_storage_buckets_policies.sql
-- Create storage buckets and policies for messaging and order proofs

begin;

-- Buckets
insert into storage.buckets (id, name, public) values ('message_attachments', 'message_attachments', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public) values ('order_proofs', 'order_proofs', false)
on conflict (id) do nothing;

-- Policies for message_attachments
create policy "message_att_read_participants"
on storage.objects for select
to authenticated
using (
  bucket_id = 'message_attachments' and
  exists (
    select 1
    from public.messages m
    join public.conversation_participants p on p.conversation_id = m.conversation_id and p.user_id = auth.uid()
    where ('message_attachments/' || m.id) = (storage.objects.name)
  )
);

create policy "message_att_insert_sender"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'message_attachments'
);

-- Policies for order_proofs
create policy "order_proofs_read_merchant_driver_admin"
on storage.objects for select
to authenticated
using (
  bucket_id = 'order_proofs' and
  (
    exists (
      select 1 from public.orders o
      where ('order_proofs/' || o.id) = (storage.objects.name)
        and (o.merchant_id = auth.uid() or o.driver_id = auth.uid())
    )
    or exists (select 1 from public.users u where u.id = auth.uid() and u.role = 'admin')
  )
);

create policy "order_proofs_insert_driver"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'order_proofs'
);

commit;

