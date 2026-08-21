-- ============================================================================
-- Questify — cross-device accounts (run after 20260814000000_init.sql).
--
--   profiles.onboarding_done : set true once the wizard is completed, so a
--                              returning user on a NEW device signs in and
--                              skips straight to the dashboard.
--   profiles.responses       : the onboarding answers (age group, focus, ...)
--                              restored on any device the user logs into.
-- ============================================================================

alter table public.profiles
  add column if not exists onboarding_done boolean not null default false;

alter table public.profiles
  add column if not exists responses jsonb not null default '{}'::jsonb;
