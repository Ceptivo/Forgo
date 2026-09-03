-- Forgo: username change cooldown + "given to charity" stat
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0007.

alter table public.profiles add column if not exists username_changed_at timestamptz;

-- Same pattern as wallet_balance_cents (0003_goals.sql): RLS can't express
-- "this column only through this function", so direct client updates to
-- username are blocked at the column-privilege level. From here on it can
-- only change via change_username below, which enforces the cooldown.
revoke update (username) on public.profiles from authenticated;

create or replace function public.change_username(p_new_username text)
returns public.profiles
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_normalized text := lower(trim(p_new_username));
  v_last_changed timestamptz;
  v_profile public.profiles;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_normalized !~ '^[a-z0-9_]{3,20}$' then
    raise exception 'Usernames are 3-20 characters: lowercase letters, numbers, underscores only';
  end if;

  select username_changed_at into v_last_changed
    from public.profiles
    where id = v_user_id
    for update;

  if v_last_changed is not null and now() - v_last_changed < interval '30 days' then
    raise exception
      'You can change your username again in % days',
      ceil(extract(epoch from (v_last_changed + interval '30 days' - now())) / 86400);
  end if;

  if exists (
    select 1 from public.profiles
    where lower(username) = v_normalized and id <> v_user_id
  ) then
    raise exception 'That username is taken';
  end if;

  update public.profiles
    set username = v_normalized, username_changed_at = now()
    where id = v_user_id
    returning * into v_profile;

  return v_profile;
end;
$$;

revoke execute on function public.change_username(text) from public, anon;
grant execute on function public.change_username(text) to authenticated;

-- Extends get_public_profile_stats (0007_profile_extras.sql) with how
-- much of a user's money has actually been forfeited to charity — the
-- only place real forfeiture is implemented so far is group goals
-- (goal_group_stakes.outcome = 'failed'); individual goals in
-- public.goals still have no failure/verification flow at all, so
-- there's nothing there yet to add to this figure.
drop function if exists public.get_public_profile_stats(uuid);

create function public.get_public_profile_stats(p_user_id uuid)
returns table (
  full_name text,
  username text,
  avatar_url text,
  follower_count int,
  following_count int,
  completed_goals_count int,
  charity_given_cents bigint,
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
    coalesce(
      (
        select sum(stake_cents) from public.goal_group_stakes
        where user_id = p_user_id and outcome = 'failed'
      ),
      0
    )::bigint,
    exists (
      select 1 from public.user_follows
      where follower_id = auth.uid() and followee_id = p_user_id
    )
  from public.profiles
  where profiles.id = p_user_id;
$$;

revoke execute on function public.get_public_profile_stats(uuid) from public, anon;
grant execute on function public.get_public_profile_stats(uuid) to authenticated;
