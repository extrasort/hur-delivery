-- Ensure driver online/offline integrity and maintenance

-- 1) Trigger to set users.is_online = true when update_driver_location is called
--    and the driver opts online via app; assumed app sets is_online as needed.
--    Here we only update last_seen_at reliably.

-- Ensure column exists
alter table if exists public.users
  add column if not exists last_seen_at timestamptz;

-- 2) Function to mark stale drivers offline (no updates for >10 minutes)
create or replace function public.mark_stale_drivers_offline()
returns void
language plpgsql
security definer
as $$
begin
  update public.users u
  set is_online = false,
      updated_at = now()
  where u.role = 'driver'
    and coalesce(u.last_seen_at, u.updated_at, u.created_at) < now() - interval '10 minutes'
    and u.is_online = true;
end;
$$;

-- 3) Schedule via cron (if pg_cron enabled) - optional comment
-- select cron.schedule('mark-stale-drivers-offline-every-2m', '*/2 * * * *', $$select public.mark_stale_drivers_offline();$$);


