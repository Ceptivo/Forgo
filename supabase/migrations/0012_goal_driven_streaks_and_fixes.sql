-- Forgo: goal-driven streaks, generic follower/following lookups,
-- self-reported goal completion, and a group-chat creation bugfix
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0011.

-- 1. Streaks must now only be built by actually completing goals — the
-- free-standing "log any activity" endpoint from 0011_streaks.sql is
-- removed. From here on, activity_check_ins can only be written by the
-- SECURITY DEFINER goal-completion functions below (both still
-- self-reported, same as everywhere else in the app — there's no
-- automated verification anywhere).
drop policy if exists "Users can log own check-ins" on public.activity_check_ins;

-- 2. Self-reported progress on a distance/time goal. A 'once' goal
-- completes and its stake is refunded; a 'weekly' goal has no fixed end
-- (see 0004_goal_activities.sql), so logging progress on it just adds
-- today to the streak without closing the goal out.
create or replace function public.log_goal_progress(p_goal_id uuid)
returns public.goals
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_goal public.goals;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_goal
    from public.goals
    where id = p_goal_id and user_id = v_user_id
    for update;

  if not found then
    raise exception 'Goal not found';
  end if;

  if v_goal.status <> 'active' then
    raise exception 'Goal is not active';
  end if;

  if v_goal.type not in ('distance', 'time') then
    raise exception 'Wrong goal type for this action';
  end if;

  insert into public.activity_check_ins (user_id, activity, logged_date)
  values (v_user_id, v_goal.distance_activity, current_date)
  on conflict (user_id, logged_date, activity) do nothing;

  if v_goal.distance_cadence = 'once' then
    update public.profiles
      set wallet_balance_cents = wallet_balance_cents + v_goal.stake_cents
      where id = v_user_id;

    update public.goals
      set status = 'completed'
      where id = p_goal_id
      returning * into v_goal;
  end if;

  return v_goal;
end;
$$;

revoke execute on function public.log_goal_progress(uuid) from public, anon;
grant execute on function public.log_goal_progress(uuid) to authenticated;

-- 3. Same self-reported completion for weight-loss goals — no activity
-- involved, so nothing to log on the heatmap, just the stake refund.
create or replace function public.complete_weight_loss_goal(p_goal_id uuid)
returns public.goals
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_goal public.goals;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_goal
    from public.goals
    where id = p_goal_id and user_id = v_user_id
    for update;

  if not found then
    raise exception 'Goal not found';
  end if;

  if v_goal.status <> 'active' then
    raise exception 'Goal is not active';
  end if;

  if v_goal.type <> 'weight_loss' then
    raise exception 'Wrong goal type for this action';
  end if;

  update public.profiles
    set wallet_balance_cents = wallet_balance_cents + v_goal.stake_cents
    where id = v_user_id;

  update public.goals
    set status = 'completed'
    where id = p_goal_id
    returning * into v_goal;

  return v_goal;
end;
$$;

revoke execute on function public.complete_weight_loss_goal(uuid) from public, anon;
grant execute on function public.complete_weight_loss_goal(uuid) to authenticated;

-- 4. Generic follower/following lookups for any user, not just the
-- caller — get_following() (0006/0007) only ever covered "who do I
-- follow"; the new Followers/Following screens need to list either side
-- for *any* profile being viewed, own or someone else's. Same SECURITY
-- DEFINER reasoning as get_following: user_follows + profiles together
-- aren't readable via plain RLS for anyone but the two people in a row.
create or replace function public.get_followers(p_user_id uuid)
returns table (user_id uuid, full_name text, username text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
  select profiles.id, profiles.full_name, profiles.username, profiles.avatar_url
  from public.user_follows
  join public.profiles on profiles.id = user_follows.follower_id
  where user_follows.followee_id = p_user_id
  order by profiles.full_name;
$$;

revoke execute on function public.get_followers(uuid) from public, anon;
grant execute on function public.get_followers(uuid) to authenticated;

create or replace function public.get_followees(p_user_id uuid)
returns table (user_id uuid, full_name text, username text, avatar_url text)
language sql
security definer set search_path = public
stable
as $$
  select profiles.id, profiles.full_name, profiles.username, profiles.avatar_url
  from public.user_follows
  join public.profiles on profiles.id = user_follows.followee_id
  where user_follows.follower_id = p_user_id
  order by profiles.full_name;
$$;

revoke execute on function public.get_followees(uuid) from public, anon;
grant execute on function public.get_followees(uuid) to authenticated;

-- 5. Bugfix: create_goal_group (0005_goal_groups.sql) generated its
-- invite code with gen_random_bytes, which lives in the pgcrypto
-- extension — not enabled on every project, and the cause of "function
-- gen_random_bytes(integer) does not exist" when starting a group chat.
-- Switched to an md5-based code that needs no extension at all. Same
-- function signature as before, so no drop-then-create needed.
create or replace function public.create_goal_group(p_name text)
returns public.goal_groups
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_group public.goal_groups;
  v_code text;
  v_attempt int := 0;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  loop
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    begin
      insert into public.goal_groups (name, invite_code, created_by)
      values (trim(p_name), v_code, v_user_id)
      returning * into v_group;
      exit;
    exception when unique_violation then
      v_attempt := v_attempt + 1;
      if v_attempt >= 5 then
        raise exception 'Could not generate a unique invite code, try again';
      end if;
    end;
  end loop;

  insert into public.goal_group_members (group_id, user_id)
  values (v_group.id, v_user_id);

  insert into public.goal_group_messages (group_id, sender_id, kind, body)
  values (v_group.id, v_user_id, 'system_join', 'Started the group');

  return v_group;
end;
$$;
