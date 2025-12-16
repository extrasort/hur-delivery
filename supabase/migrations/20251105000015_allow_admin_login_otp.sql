-- 20251105000015_allow_admin_login_otp.sql
-- Extend otp_verifications.purpose allowed values to include 'admin_login'

begin;

do $$
begin
  -- Drop existing check constraint if exists (name from earlier migration)
  if exists (
    select 1 from pg_constraint
    where conname = 'otp_verifications_purpose_check'
  ) then
    alter table public.otp_verifications
      drop constraint otp_verifications_purpose_check;
  end if;
end $$;

-- Recreate check constraint with extended allowed purposes
alter table public.otp_verifications
  add constraint otp_verifications_purpose_check
  check (purpose in ('signup','reset_password','login','admin_login'));

commit;

