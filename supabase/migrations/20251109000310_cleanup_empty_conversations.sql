begin;

-- Trigger: when the last message of a conversation is deleted, delete the conversation
create or replace function public._delete_conversation_if_empty()
returns trigger
language plpgsql
as $$
begin
  -- OLD is available on DELETE
  if not exists (
    select 1 from public.messages m where m.conversation_id = OLD.conversation_id
  ) then
    delete from public.conversations c where c.id = OLD.conversation_id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_messages_after_delete_cleanup on public.messages;
create trigger trg_messages_after_delete_cleanup
after delete on public.messages
for each row
execute function public._delete_conversation_if_empty();

-- RPC: purge empty conversations older than N minutes (defaults to 10)
create or replace function public.purge_empty_conversations(p_age_minutes int default 10)
returns integer
language plpgsql
as $$
declare
  v_deleted int := 0;
begin
  delete from public.conversations c
  where not exists (
    select 1 from public.messages m where m.conversation_id = c.id
  )
  and c.created_at < now() - ((p_age_minutes || ' minutes')::interval);
  
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

commit;

