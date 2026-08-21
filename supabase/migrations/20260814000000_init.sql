-- ============================================================================
-- Questify — initial schema. Zero-trust: RLS enforced on EVERY table.
-- All tables scope reads/writes to the authenticated user via auth.uid().
-- Run this in the Supabase SQL editor (or via `supabase db push`).
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- EXTENSIONS
-- ────────────────────────────────────────────────────────────────────────────
create extension if not exists "pgcrypto";

-- ────────────────────────────────────────────────────────────────────────────
-- PROFILES — auto-created by trigger on signup, edited by the owner.
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null default '',
  username      text not null unique,
  email         text not null default '',
  avatar        text not null default 'sun',
  provider      text not null default 'email',
  xp            integer not null default 0,
  streak        integer not null default 0,
  last_streak_date date,
  badges        jsonb not null default '[]'::jsonb,
  member_since  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Handle OAuth signups: anonymous-id fallback then a reserved-username fallback.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  base_username text;
  candidate     text;
  counter       integer := 0;
begin
  base_username := lower(coalesce(
    split_part(coalesce(new.raw_user_meta_data->>'username', ''), ' ', 1),
    ''
  ));

  if base_username = '' or base_username is null then
    base_username := 'adventurer';
  end if;
  base_username := regexp_replace(base_username, '[^a-z0-9_]', '', 'g');
  if length(base_username) > 16 then
    base_username := left(base_username, 16);
  end if;
  if base_username = '' then
    base_username := 'adventurer';
  end if;

  -- Ensure uniqueness by appending a counter.
  candidate := base_username;
  while exists (select 1 from public.profiles where username = candidate) loop
    counter := counter + 1;
    candidate := left(base_username, 16 - length(counter::text)) || counter::text;
  end loop;

  insert into public.profiles (id, display_name, username, email, avatar, provider)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', 'Quest Adventurer'),
    candidate,
    coalesce(new.raw_user_meta_data->>'email', ''),
    coalesce(new.raw_user_meta_data->>'avatar', 'sun'),
    coalesce(new.raw_user_meta_data->>'provider', 'email')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Bump updated_at on profile edits.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- HABITS — user-owned quests.
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.habits (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  title          text not null,
  icon           text not null default 'check',
  emoji          text not null default '✅',
  category       text not null default 'Wellness',
  time_of_day    text not null default '8:00 AM',
  frequency_days integer[] not null default array[1,2,3,4,5,6,7],
  is_custom      boolean not null default false,
  sort_order     integer not null default 0,
  created_at     timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────────────────────
-- HABIT_COMPLETIONS — per-user, per-day, per-habit verification ledger.
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.habit_completions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  habit_id     uuid not null references public.habits (id) on delete cascade,
  completed_on date not null default current_date,
  status       text not null default 'pending' check (status in ('pending','verified','missed')),
  proof_url    text,
  xp_awarded   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (user_id, habit_id, completed_on)
);

-- ────────────────────────────────────────────────────────────────────────────
-- QUBI_CHATS — persisted assistant conversation per user.
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.qubi_chats (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  role       text not null check (role in ('user','assistant','system')),
  content    text not null,
  tool_name  text,
  tool_state jsonb,
  created_at timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────────────────────
-- USER_SETTINGS — JSONB prefs per user (theme, haptics, notifications).
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.user_settings (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  theme_mode text not null default 'system' check (theme_mode in ('light','dark','system')),
  haptics    boolean not null default true,
  reminders_enabled boolean not null default true,
  reminder_time text not null default '08:00',
  streak_alerts boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────────────────────
alter table public.profiles         enable row level security;
alter table public.habits           enable row level security;
alter table public.habit_completions enable row level security;
alter table public.qubi_chats       enable row level security;
alter table public.user_settings    enable row level security;

-- Profiles: user may select/update only their own row; insert via trigger only.
-- (Drop-first so the whole script is safe to re-run.)
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Habits: full CRUD scoped to owner.
drop policy if exists "habits_select_own" on public.habits;
create policy "habits_select_own" on public.habits
  for select using (auth.uid() = user_id);
drop policy if exists "habits_insert_own" on public.habits;
create policy "habits_insert_own" on public.habits
  for insert with check (auth.uid() = user_id);
drop policy if exists "habits_update_own" on public.habits;
create policy "habits_update_own" on public.habits
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "habits_delete_own" on public.habits;
create policy "habits_delete_own" on public.habits
  for delete using (auth.uid() = user_id);

-- Completions: full CRUD scoped to owner.
drop policy if exists "completions_select_own" on public.habit_completions;
create policy "completions_select_own" on public.habit_completions
  for select using (auth.uid() = user_id);
drop policy if exists "completions_insert_own" on public.habit_completions;
create policy "completions_insert_own" on public.habit_completions
  for insert with check (auth.uid() = user_id);
drop policy if exists "completions_update_own" on public.habit_completions;
create policy "completions_update_own" on public.habit_completions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "completions_delete_own" on public.habit_completions;
create policy "completions_delete_own" on public.habit_completions
  for delete using (auth.uid() = user_id);

-- Chats: full CRUD scoped to owner.
drop policy if exists "chats_select_own" on public.qubi_chats;
create policy "chats_select_own" on public.qubi_chats
  for select using (auth.uid() = user_id);
drop policy if exists "chats_insert_own" on public.qubi_chats;
create policy "chats_insert_own" on public.qubi_chats
  for insert with check (auth.uid() = user_id);
drop policy if exists "chats_delete_own" on public.qubi_chats;
create policy "chats_delete_own" on public.qubi_chats
  for delete using (auth.uid() = user_id);

-- Settings: owner only.
drop policy if exists "settings_select_own" on public.user_settings;
create policy "settings_select_own" on public.user_settings
  for select using (auth.uid() = user_id);
drop policy if exists "settings_upsert_own" on public.user_settings;
create policy "settings_upsert_own" on public.user_settings
  for insert with check (auth.uid() = user_id);
drop policy if exists "settings_update_own" on public.user_settings;
create policy "settings_update_own" on public.user_settings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: USERNAME_AVAILABLE — case-insensitive uniqueness pre-check.
-- `security definer` so the app can probe availability despite the
-- select-own RLS policy; the unique index stays the real enforcement.
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.username_available(p_username text)
returns boolean
language sql
security definer set search_path = public
as $$
  select not exists (
    select 1 from public.profiles
    where lower(username) = lower(p_username)
  );
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: INCREMENT_XP — atomic XP grant (+50 per verified completion).
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.increment_xp(amount integer)
returns void
language sql
security definer set search_path = public
as $$
  update public.profiles
  set xp = xp + amount
  where id = auth.uid();
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: VERIFY_COMPLETION — atomically mark a completion verified + bank XP.
-- Guards: owner-only, not already verified, +50 XP.
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.verify_completion(
  p_completion_id uuid,
  p_proof_url text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.habit_completions
    set status = 'verified',
        proof_url = coalesce(p_proof_url, proof_url),
        xp_awarded = 50,
        updated_at = now()
  where id = p_completion_id
    and user_id = auth.uid()
    and status <> 'verified';

  if found then
    update public.profiles
      set xp = xp + 50,
          streak = streak + 1,
          last_streak_date = current_date
    where id = auth.uid();
  end if;
end;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: MARK_MISSED — user/cron marks a completion missed (no XP).
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.mark_missed(p_completion_id uuid)
returns void
language sql
security definer set search_path = public
as $$
  update public.habit_completions
    set status = 'missed', updated_at = now()
  where id = p_completion_id and user_id = auth.uid();
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- STORAGE — photo proofs. Private bucket, owner-only access.
-- ────────────────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('photo_proofs', 'photo_proofs', false)
on conflict (id) do nothing;

drop policy if exists "photo_proofs_select_own" on storage.objects;
create policy "photo_proofs_select_own"
  on storage.objects for select
  using (bucket_id = 'photo_proofs' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "photo_proofs_insert_own" on storage.objects;
create policy "photo_proofs_insert_own"
  on storage.objects for insert
  with check (bucket_id = 'photo_proofs' and (storage.foldername(name))[1] = auth.uid()::text);

-- ────────────────────────────────────────────────────────────────────────────
-- REALTIME — push completion changes to subscribers (per-user filtered).
-- Guarded so the script is safe to re-run (tables already in the publication
-- would otherwise error with "already member of publication").
-- ────────────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'habit_completions'
  ) then
    alter publication supabase_realtime add table public.habit_completions;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'habits'
  ) then
    alter publication supabase_realtime add table public.habits;
  end if;
end $$;
