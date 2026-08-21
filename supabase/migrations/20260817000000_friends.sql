-- ============================================================================
-- Questify — friend system + social features (run after accounts migration).
--
--   friend_requests   : inbound/outbound friend requests (pending/accepted/declined)
--   friendships       : bidirectional accepted friend links
--   profiles.league   : league tier (gold/silver/bronze/platinum/diamond)
--   RPC: send_friend_request, accept_friend_request, decline_friend_request
--   RPC: remove_friend, search_users, get_friends, get_leaderboard
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- PROFILES — add league column
-- ────────────────────────────────────────────────────────────────────────────
alter table public.profiles
  add column if not exists league text not null default 'bronze'
  check (league in ('bronze','silver','gold','platinum','diamond'));

-- ────────────────────────────────────────────────────────────────────────────
-- FRIEND_REQUESTS — pending requests between users
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.friend_requests (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid not null references auth.users (id) on delete cascade,
  receiver_id uuid not null references auth.users (id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at  timestamptz not null default now(),
  unique (sender_id, receiver_id)
);

-- Prevent duplicate pending requests.
create unique index if not exists idx_friend_requests_unique_pending
  on public.friend_requests (sender_id, receiver_id)
  where status = 'pending';

-- ────────────────────────────────────────────────────────────────────────────
-- FRIENDSHIPS — bidirectional accepted links (both directions stored for fast lookup)
-- ────────────────────────────────────────────────────────────────────────────
create table if not exists public.friendships (
  user_a_id uuid not null references auth.users (id) on delete cascade,
  user_b_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a_id, user_b_id),
  check (user_a_id < user_b_id)  -- canonical ordering for dedup
);

-- ────────────────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────────────────────
alter table public.friend_requests enable row level security;
alter table public.friendships     enable row level security;

-- Friend requests: sender or receiver can read; sender inserts; either updates (accept/decline).
drop policy if exists "fr_select_own" on public.friend_requests;
create policy "fr_select_own" on public.friend_requests
  for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "fr_insert_own" on public.friend_requests;
create policy "fr_insert_own" on public.friend_requests
  for insert with check (auth.uid() = sender_id);

drop policy if exists "fr_update_own" on public.friend_requests;
create policy "fr_update_own" on public.friend_requests
  for update using (auth.uid() = receiver_id)
  with check (auth.uid() = receiver_id);

drop policy if exists "fr_delete_own" on public.friend_requests;
create policy "fr_delete_own" on public.friend_requests
  for delete using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Friendships: either party can read; insert/delete via RPC (security definer).
drop policy if exists "fs_select_own" on public.friendships;
create policy "fs_select_own" on public.friendships
  for select using (auth.uid() = user_a_id or auth.uid() = user_b_id);

-- Profiles: allow reading other users for search (read-only for non-owner).
drop policy if exists "profiles_select_public" on public.profiles;
create policy "profiles_select_public" on public.profiles
  for select using (true);

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: SEARCH_USERS — find users by username (for adding friends)
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.search_users(p_query text, p_limit integer default 20)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar text,
  xp integer,
  streak integer,
  league text
)
language sql
security definer set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar, p.xp, p.streak, p.league
  from public.profiles p
  where lower(p.username) like '%' || lower(p_query) || '%'
    and p.id <> auth.uid()
  order by p.xp desc
  limit p_limit;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: SEND_FRIEND_REQUEST — create or accept a pending request
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.send_friend_request(p_receiver_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  reverse_pending boolean;
begin
  -- Cannot friend yourself.
  if p_receiver_id = auth.uid() then
    raise exception 'Cannot send a friend request to yourself';
  end if;

  -- Check if reverse request exists → auto-accept.
  select exists(
    select 1 from public.friend_requests
    where sender_id = p_receiver_id
      and receiver_id = auth.uid()
      and status = 'pending'
  ) into reverse_pending;

  if reverse_pending then
    -- Auto-accept: update the existing request.
    update public.friend_requests
      set status = 'accepted'
    where sender_id = p_receiver_id
      and receiver_id = auth.uid()
      and status = 'pending';

    -- Create bidirectional friendship (canonical ordering: a < b).
    insert into public.friendships (user_a_id, user_b_id)
    select
      case when auth.uid() < p_receiver_id then auth.uid() else p_receiver_id end,
      case when auth.uid() < p_receiver_id then p_receiver_id else auth.uid() end
    on conflict do nothing;
  else
    -- Insert new pending request.
    insert into public.friend_requests (sender_id, receiver_id, status)
    values (auth.uid(), p_receiver_id, 'pending')
    on conflict do nothing;
  end if;
end;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: ACCEPT_FRIEND_REQUEST — receiver accepts a pending request
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.accept_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  req record;
begin
  select * into req from public.friend_requests
  where id = p_request_id and receiver_id = auth.uid() and status = 'pending';

  if not found then
    raise exception 'Request not found or already handled';
  end if;

  update public.friend_requests
    set status = 'accepted'
  where id = p_request_id;

  insert into public.friendships (user_a_id, user_b_id)
  select
    case when req.sender_id < req.receiver_id then req.sender_id else req.receiver_id end,
    case when req.sender_id < req.receiver_id then req.receiver_id else req.sender_id end
  on conflict do nothing;
end;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: DECLINE_FRIEND_REQUEST — receiver declines a pending request
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.decline_friend_request(p_request_id uuid)
returns void
language sql
security definer set search_path = public
as $$
  update public.friend_requests
    set status = 'declined'
  where id = p_request_id and receiver_id = auth.uid() and status = 'pending';
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: REMOVE_FRIEND — remove a bidirectional friendship
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.remove_friend(p_friend_id uuid)
returns void
language sql
security definer set search_path = public
as $$
  delete from public.friendships
  where (
    (user_a_id = auth.uid() and user_b_id = p_friend_id) or
    (user_a_id = p_friend_id and user_b_id = auth.uid())
  );
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: GET_FRIENDS — list all accepted friends with profile data
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.get_friends()
returns table (
  id uuid,
  username text,
  display_name text,
  avatar text,
  xp integer,
  streak integer,
  league text,
  last_streak_date date
)
language sql
security definer set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar, p.xp, p.streak, p.league, p.last_streak_date
  from public.profiles p
  inner join public.friendships f
    on (f.user_a_id = auth.uid() and f.user_b_id = p.id)
    or (f.user_b_id = auth.uid() and f.user_a_id = p.id)
  order by p.xp desc;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: GET_FRIEND_REQUESTS — list pending inbound requests
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.get_friend_requests()
returns table (
  request_id uuid,
  sender_id uuid,
  username text,
  display_name text,
  avatar text,
  created_at timestamptz
)
language sql
security definer set search_path = public
as $$
  select fr.id as request_id, fr.sender_id,
         p.username, p.display_name, p.avatar, fr.created_at
  from public.friend_requests fr
  inner join public.profiles p on p.id = fr.sender_id
  where fr.receiver_id = auth.uid() and fr.status = 'pending'
  order by fr.created_at desc;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- RPC: GET_LEADERBOARD — top users for the league page
-- ────────────────────────────────────────────────────────────────────────────
create or replace function public.get_leaderboard(p_limit integer default 50)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar text,
  xp integer,
  streak integer,
  league text,
  rank_num bigint
)
language sql
security definer set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar, p.xp, p.streak, p.league,
         row_number() over (order by p.xp desc) as rank_num
  from public.profiles p
  order by p.xp desc
  limit p_limit;
$$;
