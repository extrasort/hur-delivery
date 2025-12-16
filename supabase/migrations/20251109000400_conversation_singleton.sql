begin;

-- Ensure we don't create duplicate support conversations:
-- If p_order_id is null, reuse an existing is_support conversation created by the same user.
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
    select id into v_conversation_id
    from public.conversations
    where order_id = p_order_id and is_support = coalesce(p_is_support,false)
    limit 1;
  else
    if coalesce(p_is_support,false) then
      -- Reuse an existing support conversation created by this user
      select id into v_conversation_id
      from public.conversations
      where is_support = true
        and created_by = auth.uid()
      order by created_at desc
      limit 1;
    end if;
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

commit;

