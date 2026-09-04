-- Forgo: the Forgo community — a real, always-joinable space every user
-- is automatically a member of, built entirely on the existing group-goal
-- machinery (goal_groups/goal_group_goals/goal_group_stakes) rather than
-- a parallel system. The only things special about it: everyone is a
-- member from the moment they sign up, and there's no chat — just
-- goal(s) to join and a leaderboard. Rounds are seeded by hand (see the
-- template at the bottom), same pattern as feature_candidates/charities
-- — there's no in-app admin role/UI for this.
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Run it after 0001-0014.

-- Fixed id so the Flutter app can reference this exact row (see
-- kCommunityGroupId in lib/features/groups). created_by has to be a
-- real user (the column is not null), so this picks whichever account
-- signed up first — that value is never shown anywhere, it's just to
-- satisfy the foreign key.
do $$
declare
  v_creator uuid;
begin
  select id into v_creator from auth.users order by created_at limit 1;
  if v_creator is not null then
    insert into public.goal_groups (id, name, bio, invite_code, created_by)
    values (
      '00000000-0000-0000-0000-000000000001',
      'Forgo',
      'Made for the community',
      'FORGOCM',
      v_creator
    )
    on conflict (id) do nothing;
  end if;
end $$;

-- Every existing user is a member from today...
insert into public.goal_group_members (group_id, user_id)
select '00000000-0000-0000-0000-000000000001', id
from auth.users
where exists (
  select 1 from public.goal_groups where id = '00000000-0000-0000-0000-000000000001'
)
on conflict (group_id, user_id) do nothing;

-- ...and every new signup joins it automatically too. Same
-- handle_new_user() as 0007_profile_extras.sql, with one line added —
-- guarded by "if the community group exists" so a signup never breaks
-- even if that row is ever removed.
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

  if exists (
    select 1 from public.goal_groups where id = '00000000-0000-0000-0000-000000000001'
  ) then
    insert into public.goal_group_members (group_id, user_id)
    values ('00000000-0000-0000-0000-000000000001', new.id)
    on conflict (group_id, user_id) do nothing;
  end if;

  return new;
end;
$$;

-- Everything else — start_goal_group_round/join_goal_group_round/
-- report_goal_group_outcome/the leaderboard — already works against any
-- group id, this one included, with zero new code. The one exception:
-- goal_group_goals_one_active_per_group_idx (0005_goal_groups.sql) is a
-- *database-level* unique index limiting every group to one active round
-- at a time, not just an app-side check — and the community wants daily
-- *and* weekly goals running together. Rather than weaken that guarantee
-- for normal groups too, this carves out the one group id it doesn't
-- apply to.
drop index if exists public.goal_group_goals_one_active_per_group_idx;

create unique index goal_group_goals_one_active_per_group_idx
  on public.goal_group_goals (group_id)
  where status = 'active'
    and group_id <> '00000000-0000-0000-0000-000000000001';

-- The community's rounds are seeded directly (bypassing
-- start_goal_group_round, which the SQL editor can't call anyway — it
-- has no auth.uid() session, and that RPC would block a second active
-- round regardless). Add one with:
--
--   insert into public.goal_group_goals (
--     group_id, started_by, type, stake_cents, deadline,
--     distance_km, distance_cadence, distance_activity
--   ) values (
--     '00000000-0000-0000-0000-000000000001',
--     (select id from auth.users order by created_at limit 1),
--     'distance', 2000, null,
--     5, 'weekly', 'run'
--   );
--
-- (stake_cents is in cents — 2000 = R20. Leave deadline null and
-- distance_cadence 'weekly' for an ongoing weekly goal; set a deadline
-- and distance_cadence 'once' for a one-off. Group rounds only support
-- type 'distance' or 'weight_loss' — same as start_goal_group_round —
-- there's no group-round equivalent of the individual 'time' goal type.
-- For weight_loss: set type = 'weight_loss', weight_loss_target_kg
-- instead of the distance_* columns, and deadline is required.)
