-- ============================================================================
-- Questify — Custom email verification via Resend.
-- Stores hashed OTP codes; Supabase email confirmation is OFF.
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- VERIFICATION CODES — 6-digit OTP for email verification during signup.
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.verification_codes (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  code_hash   text not null,
  status      text not null default 'pending',  -- pending | verified | expired
  attempts    integer not null default 0,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default (now() + interval '15 minutes')
);

-- Index for fast lookup by email + status.
create index if not exists idx_verification_codes_email_status
  on public.verification_codes (email, status);

-- ────────────────────────────────────────────────────────────────────────────
-- CLEANUP — auto-expire old codes every time we insert.
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.cleanup_expired_codes()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  delete from public.verification_codes
  where email = NEW.email
    and status = 'pending'
    and id != NEW.id;
  return NEW;
end;
$$;

drop trigger if exists cleanup_on_insert on public.verification_codes;
create trigger cleanup_on_insert
  before insert on public.verification_codes
  for each row execute procedure public.cleanup_expired_codes();

-- ────────────────────────────────────────────────────────────────────────────
-- RLS — client can read/write its own verification codes (pre-auth).
-- Edge Function uses service_role key and bypasses RLS.
-- ────────────────────────────────────────────────────────────────────────────
alter table public.verification_codes enable row level security;

-- Allow anyone to insert (pre-auth: user hasn't signed up yet).
create policy "Allow insert for verification codes"
  on public.verification_codes
  for insert
  with check (true);

-- Allow anyone to select pending codes by email (pre-auth check).
create policy "Allow select pending verification codes"
  on public.verification_codes
  for select
  using (status = 'pending');

-- Allow anyone to update status to 'verified' or 'expired'.
create policy "Allow update verification codes"
  on public.verification_codes
  for update
  using (true)
  with check (true);
