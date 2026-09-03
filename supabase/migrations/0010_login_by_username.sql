-- Forgo: log in with username as well as email
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0009.
--
-- Supabase Auth only signs in by email (or phone) — there's no native
-- "sign in by username". The login screen resolves a username to its
-- email client-side by calling this first, then signs in with that
-- email as normal. Granted to `anon` (not just `authenticated`) because
-- this has to work *before* the user is signed in — that's also why it's
-- narrowly scoped to return only an email, never anything else from
-- profiles.
create or replace function public.get_email_for_username(p_username text)
returns text
language sql
security definer set search_path = public
stable
as $$
  select email from public.profiles
  where lower(username) = lower(trim(p_username))
  limit 1;
$$;

revoke execute on function public.get_email_for_username(text) from public;
grant execute on function public.get_email_for_username(text) to anon, authenticated;
