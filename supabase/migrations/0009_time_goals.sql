-- Forgo: Time goals (run/walk/cycle/swim for N minutes)
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0008.
--
-- A third individual-goal type alongside distance and weight_loss —
-- "run for 20 min", "cycle for 1 hour" etc. Reuses distance_activity
-- (run/walk/cycle/swim) and distance_cadence (once/weekly) since a time
-- goal needs exactly the same two choices a distance goal does; only the
-- measured quantity differs (minutes instead of km), hence the new
-- time_minutes column. Verified the same way as the other two types (a
-- screenshot) — no automated verification exists for any individual goal
-- yet, same caveat as 0003_goals.sql.

alter table public.goals drop constraint if exists goals_fields_match_type;
alter table public.goals drop constraint if exists goals_type_check;

alter table public.goals add column if not exists time_minutes int;

alter table public.goals
  add constraint goals_type_check check (type in ('distance', 'weight_loss', 'time'));

alter table public.goals
  add constraint goals_time_minutes_positive check (time_minutes is null or time_minutes > 0);

alter table public.goals
  add constraint goals_fields_match_type check (
    (
      type = 'distance'
      and distance_km is not null
      and distance_cadence is not null
      and distance_activity is not null
      and weight_loss_target_kg is null
      and time_minutes is null
      and (distance_cadence = 'once') = (deadline is not null)
    )
    or (
      type = 'time'
      and time_minutes is not null
      and distance_cadence is not null
      and distance_activity is not null
      and distance_km is null
      and weight_loss_target_kg is null
      and (distance_cadence = 'once') = (deadline is not null)
    )
    or (
      type = 'weight_loss'
      and weight_loss_target_kg is not null
      and distance_km is null
      and distance_cadence is null
      and distance_activity is null
      and time_minutes is null
      and deadline is not null
    )
  );

-- New time_minutes param, so (same reasoning as 0004_goal_activities.sql)
-- the old signature has to be dropped before recreating — CREATE OR
-- REPLACE can't change a function's parameter list, only its body.
drop function if exists public.create_goal_with_stake(
  text, bigint, date, numeric, text, text, numeric
);

create or replace function public.create_goal_with_stake(
  p_type text,
  p_stake_cents bigint,
  p_deadline date,
  p_distance_km numeric default null,
  p_distance_cadence text default null,
  p_distance_activity text default null,
  p_weight_loss_target_kg numeric default null,
  p_time_minutes int default null
)
returns public.goals
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_balance bigint;
  v_goal public.goals;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_stake_cents <= 0 then
    raise exception 'Stake must be greater than zero';
  end if;

  select wallet_balance_cents into v_balance
    from public.profiles
    where id = v_user_id
    for update;

  if v_balance is null then
    raise exception 'Profile not found';
  end if;

  if v_balance < p_stake_cents then
    raise exception 'Insufficient wallet balance';
  end if;

  update public.profiles
    set wallet_balance_cents = wallet_balance_cents - p_stake_cents
    where id = v_user_id;

  insert into public.goals (
    user_id, type, stake_cents, deadline,
    distance_km, distance_cadence, distance_activity, weight_loss_target_kg,
    time_minutes
  ) values (
    v_user_id, p_type, p_stake_cents, p_deadline,
    p_distance_km, p_distance_cadence, p_distance_activity,
    p_weight_loss_target_kg, p_time_minutes
  )
  returning * into v_goal;

  return v_goal;
end;
$$;

revoke execute on function public.create_goal_with_stake(
  text, bigint, date, numeric, text, text, numeric, int
) from public, anon;
grant execute on function public.create_goal_with_stake(
  text, bigint, date, numeric, text, text, numeric, int
) to authenticated;
