-- 20251105000012_driver_availability_rules.sql
-- Introduces a robust driver availability check that:
--   * Prefers online drivers without active orders
--   * Allows multi-assignment to drivers already serving the same merchant
--     when no free drivers exist
--   * Respects vehicle type requirements
-- Returns a JSON payload describing availability and diagnostic counts

begin;

create or replace function public.validate_driver_availability_for_merchant(
  p_vehicle_type text,
  p_merchant_id uuid
)
returns jsonb
language plpgsql
as $$
declare
  v_vehicle_type text := nullif(trim(coalesce(p_vehicle_type, '')), '');
  v_free_count int := 0;
  v_same_merchant_count int := 0;
begin
  with online_drivers as (
    select u.id
    from public.users u
    where u.role = 'driver'
      and u.is_online = true
      and (v_vehicle_type is null or u.vehicle_type = v_vehicle_type)
  ),
  active_orders as (
    select o.driver_id, o.merchant_id
    from public.orders o
    where o.driver_id is not null
      and o.status in ('pending', 'assigned', 'accepted', 'on_the_way')
  ),
  free_driver_candidates as (
    select d.id
    from online_drivers d
    left join active_orders ao on ao.driver_id = d.id
    where ao.driver_id is null
  ),
  same_merchant_drivers as (
    select ao.driver_id
    from active_orders ao
    join online_drivers d on d.id = ao.driver_id
    group by ao.driver_id
    having count(*) filter (where ao.merchant_id = p_merchant_id) > 0
       and count(*) = count(*) filter (where ao.merchant_id = p_merchant_id)
  )
  select count(*) into v_free_count from free_driver_candidates;

  select count(*) into v_same_merchant_count from same_merchant_drivers;

  if v_free_count > 0 then
    return jsonb_build_object(
      'available', true,
      'reason', 'free_driver_available',
      'free_driver_count', v_free_count,
      'same_merchant_driver_count', v_same_merchant_count
    );
  elsif v_same_merchant_count > 0 then
    return jsonb_build_object(
      'available', true,
      'reason', 'same_merchant_driver_available',
      'free_driver_count', v_free_count,
      'same_merchant_driver_count', v_same_merchant_count
    );
  else
    return jsonb_build_object(
      'available', false,
      'reason', 'no_driver_available',
      'free_driver_count', v_free_count,
      'same_merchant_driver_count', v_same_merchant_count
    );
  end if;
end;
$$;

comment on function public.validate_driver_availability_for_merchant(text, uuid) is
  'Checks driver availability considering vehicle type, free drivers, and multi-assignment rules for the same merchant.';

commit;

