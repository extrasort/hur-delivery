begin;

grant usage on schema public to authenticated;
grant usage on schema public to anon;

grant select on public.users to authenticated;
grant select on public.users to anon;

grant insert on public.conversations to authenticated;
grant insert on public.conversations to anon;

grant insert on public.conversation_participants to authenticated;
grant insert on public.conversation_participants to anon;
grant select on public.conversation_participants to authenticated;
grant select on public.conversation_participants to anon;

grant execute on function public.create_or_get_conversation(uuid, uuid[], boolean) to authenticated;
grant execute on function public.create_or_get_conversation(uuid, uuid[], boolean) to anon;

grant execute on function public.send_message(uuid, text, text, uuid) to authenticated;
grant execute on function public.send_message(uuid, text, text, uuid) to anon;

alter table public.conversations disable row level security;
alter table public.conversation_participants disable row level security;
alter table public.messages disable row level security;

commit;

