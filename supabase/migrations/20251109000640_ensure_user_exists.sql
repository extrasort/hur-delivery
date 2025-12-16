begin;

-- Upserter for public.users that can be safely called by authenticated clients
create or replace function public.ensure_user_exists(
  p_id uuid,
  p_name text default 'Admin',
  p_role text default 'admin',
  p_phone text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_id is null then
    raise exception 'MISSING_USER_ID';
  end if;
  insert into public.users(id, name, role, phone, is_online, created_at)
  values (p_id, coalesce(nullif(p_name, ''), 'Admin'), coalesce(nullif(p_role, ''), 'admin'), p_phone, true, now())
  on conflict (id) do update
    set name = excluded.name,
        role = excluded.role,
        phone = coalesce(excluded.phone, public.users.phone),
        updated_at = now();
end;
$$;

grant execute on function public.ensure_user_exists(uuid, text, text, text) to authenticated;

commit;

