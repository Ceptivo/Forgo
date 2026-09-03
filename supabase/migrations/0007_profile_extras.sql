-- Forgo: usernames, editable nicknames, and avatar photos
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0006.
--
-- Adds a permanent, unique `username` (chosen at signup) alongside the
-- existing `full_name`, which now doubles as the editable "nickname" —
-- duplicates allowed, changeable any time from the profile screen. Also
-- adds `avatar_url` and a public `avatars` storage bucket so a profile
-- photo is visible to anyone who looks the user up.

alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists avatar_url text;

-- Backfill any existing rows (signed up before this migration) with a
-- generated placeholder so the NOT NULL + UNIQUE constraints below can be
-- added safely. They can change it later the same way anyone else would.
update public.profiles
  set username = 'user_' || substr(replace(id::text, '-', ''), 1, 10)
  where username is null;

alter table public.profiles alter column username set not null;

alter table public.profiles
  add constraint profiles_username_format
  check (username ~ '^[a-z0-9_]{3,20}$');

create unique index if not exists profiles_username_unique_idx
  on public.profiles (lower(username));

-- Signup now passes a username alongside full_name/date_of_birth (see
-- AuthRepository.signUp in the Flutter app) — this trigger just needs to
-- read and insert the extra field. If the username is already taken, the
-- unique index above raises inside this trigger, which aborts the whole
-- signUp() call (including the auth.users row) rather than leaving an
-- orphaned auth user with no profile.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, date_of_birth, username)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    (new.raw_user_meta_data ->> 'date_of_birth')::date,
    new.raw_user_meta_data ->> 'username'
  );
  return new;
end;
$$;

-- Lets the signup form check availability before submitting, for
-- immediate feedback — granted to `anon` too since this runs before the
-- user has a session. The unique index is still the actual enforcement;
-- this is just a friendlier pre-check.
create or replace function public.is_username_available(p_username text)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select not exists (
    select 1 from public.profiles where lower(username) = lower(p_username)
  );
$$;

revoke execute on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to authenticated, anon;

-- search_profiles, get_following, and get_public_profile_stats
-- (0006_social.sql) all need their return shape extended with
-- username + avatar_url — CREATE OR REPLACE can't change a function's
-- return columns, so each has to be dropped first.

drop function if exists public.search_profiles(text);

create function public.search_profiles(p_query text)
returns table (user_id uuid, full_name text, username text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
  select id, full_name, username, avatar_url
  from public.profiles
  where id <> auth.uid()
    and (full_name ilike '%' || trim(p_query) || '%'
         or username ilike '%' || trim(p_query) || '%')
  order by full_name
  limit 20;
$$;

revoke execute on function public.search_profiles(text) from public, anon;
grant execute on function public.search_profiles(text) to authenticated;

drop function if exists public.get_following();

create function public.get_following()
returns table (user_id uuid, full_name text, username text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
  select profiles.id, profiles.full_name, profiles.username, profiles.avatar_url
  from public.user_follows
  join public.profiles on profiles.id = user_follows.followee_id
  where user_follows.follower_id = auth.uid()
  order by profiles.full_name;
$$;

revoke execute on function public.get_following() from public, anon;
grant execute on function public.get_following() to authenticated;

drop function if exists public.get_public_profile_stats(uuid);

create function public.get_public_profile_stats(p_user_id uuid)
returns table (
  full_name text,
  username text,
  avatar_url text,
  follower_count int,
  following_count int,
  completed_goals_count int,
  is_following boolean
)
language sql
security definer set search_path = public
stable
as $$
  select
    profiles.full_name,
    profiles.username,
    profiles.avatar_url,
    (select count(*) from public.user_follows where followee_id = p_user_id)::int,
    (select count(*) from public.user_follows where follower_id = p_user_id)::int,
    (select count(*) from public.goals where user_id = p_user_id and status = 'completed')::int,
    exists (
      select 1 from public.user_follows
      where follower_id = auth.uid() and followee_id = p_user_id
    )
  from public.profiles
  where profiles.id = p_user_id;
$$;

revoke execute on function public.get_public_profile_stats(uuid) from public, anon;
grant execute on function public.get_public_profile_stats(uuid) to authenticated;

drop function if exists public.get_goal_group_member_names(uuid);

create function public.get_goal_group_member_names(p_group_id uuid)
returns table (user_id uuid, full_name text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
  select profiles.id, profiles.full_name, profiles.avatar_url
  from public.profiles
  join public.goal_group_members on goal_group_members.user_id = profiles.id
  where goal_group_members.group_id = p_group_id
    and public.is_goal_group_member(p_group_id);
$$;

revoke execute on function public.get_goal_group_member_names(uuid) from public, anon;
grant execute on function public.get_goal_group_member_names(uuid) to authenticated;

-- Public avatar storage: anyone can view (so a photo shows up when
-- another user searches for you), but a user can only write inside their
-- own folder (avatars/<user_id>/...).
insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do nothing;

create policy "Avatar images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "Users can upload their own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
