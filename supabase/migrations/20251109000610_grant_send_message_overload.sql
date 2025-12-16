begin;

grant execute on function public.send_message(uuid, text, text, uuid, uuid, uuid) to authenticated;
grant execute on function public.send_message(uuid, text, text, uuid, uuid, uuid) to anon;

commit;

