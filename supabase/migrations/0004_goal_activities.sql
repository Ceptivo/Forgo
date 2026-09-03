-- Forgo: broaden run goals into distance goals (run/walk/cycle/swim)
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0003.
--
-- What changes: the 'run' goal type becomes 'distance', with a new
-- distance_activity column (run/walk/cycle/swim) — all four are verified
-- the same way (a screenshot from whatever fitness app the user already
-- uses), so they're one goal type with an activity choice rather than
-- four separate types. Existing 'run' rows (if any) are migrated to
-- type='distance', distance_activity='run' — no data is dropped.

alter table public.goals drop constraint if exists goals_fields_match_type;
alter table public.goals drop constraint if exists goals_type_check;
alter table public.goals drop constraint if exists goals_run_cadence_check;

alter table public.goals rename column run_distance_km to distance_km;
alter table public.goals rename column run_cadence to distance_cadence;
alter table public.goals add column if not exists distance_activity text;

update public.goals
  set distance_activity = 'run'
  where type = 'run' and distance_activity is null;

update public.goals
  set type = 'distance'
  where type = 'run';

alter table public.goals
  add constraint goals_type_check check (type in ('distance', 'weight_loss'));

alter table public.goals
  add constraint goals_distance_cadence_check
  check (distance_cadence in ('once', 'weekly'));

alter table public.goals
  add constraint goals_distance_activity_check
  check (distance_activity in ('run', 'walk', 'cycle', 'swim'));

alter table public.goals
  add constraint goals_fields_match_type check (
    (
      type = 'distance'
      and distance_km is not null
      and distance_cadence is not null
      and distance_activity is not null
      and weight_loss_target_kg is null
      and (distance_cadence = 'once') = (deadline is not null)
    )
    or (
      type = 'weight_loss'
      and weight_loss_target_kg is not null
      and distance_km is null
      and distance_cadence is null
      and distance_activity is null
      and deadline is not null
    )
  );

-- Parameter list changed (added p_distance_activity, renamed the run_*
-- params), so the old function signature needs dropping first — CREATE OR
-- REPLACE can't change a function's parameter list, only its body.
drop function if exists public.create_goal_with_stake(
  text, bigint, date, numeric, text, numeric
);

create or replace function public.create_goal_with_stake(
  p_type text,
  p_stake_cents bigint,
  p_deadline date,
  p_distance_km numeric default null,
  p_distance_cadence text default null,
  p_distance_activity text default null,
  p_weight_loss_target_kg numeric default null
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
    distance_km, distance_cadence, distance_activity, weight_loss_target_kg
  ) values (
    v_user_id, p_type, p_stake_cents, p_deadline,
    p_distance_km, p_distance_cadence, p_distance_activity,
    p_weight_loss_target_kg
  )
  returning * into v_goal;

  return v_goal;
end;
$$;

revoke execute on function public.create_goal_with_stake(
  text, bigint, date, numeric, text, text, numeric
) from public, anon;
grant execute on function public.create_goal_with_stake(
  text, bigint, date, numeric, text, text, numeric
) to authenticated;
