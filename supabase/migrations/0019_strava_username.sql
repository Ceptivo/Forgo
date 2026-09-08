-- Forgo: a Strava username field on profiles (Settings > Strava)
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Run it after 0001-0018.
--
-- Just a stored reference, not a real Strava connection — no OAuth, no
-- API calls to Strava, same self-reported character as everything else
-- in the app. No RPC needed either: it's a plain nullable column a user
-- updates on their own profile, same as full_name (see
-- ProfileRepository.updateFullName) — already covered by profiles'
-- existing "Users can update own profile" RLS policy, which only locks
-- down wallet_balance_cents specifically (0003_goals.sql).
alter table public.profiles
  add column if not exists strava_username text;
