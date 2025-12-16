-- Create table to store OTP verifications
create table if not exists public.otp_verifications (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  purpose text not null check (purpose in ('signup','reset_password')),
  code text not null,
  expires_at timestamptz not null,
  attempts int not null default 0,
  max_attempts int not null default 5,
  consumed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists otp_verifications_phone_idx on public.otp_verifications (phone);
create index if not exists otp_verifications_expires_idx on public.otp_verifications (expires_at);

-- Row Level Security: only service role should access directly; app uses edge functions
alter table public.otp_verifications enable row level security;

do $$ begin
  create policy otp_verifications_no_access on public.otp_verifications
    for all using (false) with check (false);
exception when duplicate_object then null; end $$;

-- Helper function to purge expired/consumed OTPs
create or replace function public.purge_old_otps() returns void language plpgsql as $$
begin
  delete from public.otp_verifications
  where (expires_at < now() - interval '1 day') or consumed = true;
end;$$;

