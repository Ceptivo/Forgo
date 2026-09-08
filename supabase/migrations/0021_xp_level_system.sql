-- Forgo: XP & Level system (spec v1.5, "Forgo XP & Level System")
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Run it after 0001-0020.
--
-- Scope for this first version — the full spec also covers donation XP
-- (charity + direct-to-app), payment chargeback clawback, Strava-screenshot
-- AI cross-verification, and FICA-driven multi-account prevention. None of
-- those exist as features in the app yet (there's no donation flow at all,
-- no chargeback webhook handling distinct from the top-up one, and
-- verification is deliberately still manual per the spec's own June-2026
-- Strava ToS finding). This migration implements everything the spec
-- defines that has a real, existing action to hook into:
--   - Goal-completion XP (stake base XP x effort multiplier), with the
--     required anti-spam rules: one shared daily XP slot per category
--     (distance vs duration), a minimum-plausible-duration check, and 0 XP
--     for anything that isn't a genuine successful completion.
--   - Streak-milestone XP (4/12/26/52-week, then every 26 weeks per the
--     1,800 + 400*n formula), paid once per continuous streak run and
--     reset when a streak breaks.
--   - Community Challenge placement XP, mapped onto the one challenge
--     feature that exists (the "No Turning Back" league): top-10 finishers
--     by the same authoritative time-ranking finalize_league already uses,
--     gated on 10+ entrants per the spec's min-field-size rule.
-- Level display is computed client-side from profiles.xp (pure function of
-- the formula below — no need for a level column or an RPC round trip).

-- 1. profiles.xp — same lockdown pattern as wallet_balance_cents (0003):
-- RLS lets a user read their own row already; only SECURITY DEFINER
-- functions below are ever allowed to change it.
alter table public.profiles add column if not exists xp bigint not null default 0;
alter table public.profiles add constraint profiles_xp_non_negative check (xp >= 0);
revoke update (xp) on public.profiles from authenticated;

-- 2. Audit trail — also doubles as the "already awarded today" check for
-- the per-category daily cap (query below). Not writable by clients.
create table if not exists public.xp_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  category text, -- 'distance' | 'duration' | 'weight_loss' | 'streak' | 'challenge'
  amount int not null,
  reason text not null,
  goal_id uuid references public.goals (id) on delete set null,
  league_id uuid references public.leagues (id) on delete set null,
  streak_week int,
  created_at timestamptz not null default now()
);

create index if not exists xp_events_user_category_day_idx
  on public.xp_events (user_id, category, created_at);

alter table public.xp_events enable row level security;

create policy "Users can view own xp events"
  on public.xp_events for select
  using (auth.uid() = user_id);

-- No insert/update/delete policy for authenticated — xp_events only ever
-- gets written by the SECURITY DEFINER functions below.

-- 3. Award-once tracking for streak milestones (Medium Finding #4).
create table if not exists public.streak_milestone_awards (
  user_id uuid not null references auth.users (id) on delete cascade,
  milestone_week int not null,
  awarded_at timestamptz not null default now(),
  primary key (user_id, milestone_week)
);

alter table public.streak_milestone_awards enable row level security;

create policy "Users can view own streak milestone awards"
  on public.streak_milestone_awards for select
  using (auth.uid() = user_id);

-- 4. Pure computation helpers — no table access, safe to grant broadly
-- (mirrors the is_forgo_founder()/league_day_release_at() pattern from
-- 0017: every function gets an explicit revoke-then-grant regardless of
-- how "safe" it looks, so nothing is ever left on the implicit PUBLIC
-- default).

create or replace function public.xp_stake_base(p_stake_cents bigint)
returns int
language sql
immutable
as $$
  select case
    when p_stake_cents >= 20000 then 70  -- R200+
    when p_stake_cents >= 10000 then 50  -- R100
    when p_stake_cents >= 5000 then 35   -- R50
    when p_stake_cents >= 2000 then 25   -- R20
    else 20                              -- R10 and below
  end;
$$;

revoke execute on function public.xp_stake_base(bigint) from public, anon;
grant execute on function public.xp_stake_base(bigint) to authenticated;

-- Distance effort multiplier. Swim isn't in the spec's distance table (it
-- only gives walk/run/cycle bands — swim is assumed duration-based there),
-- but this app allows a distance-type swim goal too, so bands are added
-- here scaled roughly to swim pace being ~4-5x slower than running for
-- comparable effort. Easy to retune later if that doesn't feel right.
create or replace function public.xp_distance_multiplier(p_activity text, p_km numeric)
returns numeric
language sql
immutable
as $$
  select case p_activity
    when 'walk' then case
      when p_km < 1 then 0.5 when p_km < 3 then 1.0 when p_km < 6 then 1.5
      when p_km < 10 then 2.0 else 2.5 end
    when 'run' then case
      when p_km < 1 then 0.5 when p_km < 5 then 1.0 when p_km < 10 then 1.5
      when p_km < 21 then 2.0 else 2.5 end
    when 'cycle' then case
      when p_km < 3 then 0.5 when p_km < 15 then 1.0 when p_km < 40 then 1.5
      when p_km < 80 then 2.0 else 2.5 end
    when 'swim' then case
      when p_km < 0.25 then 0.5 when p_km < 0.75 then 1.0 when p_km < 1.5 then 1.5
      when p_km < 3 then 2.0 else 2.5 end
    else 1.0
  end;
$$;

revoke execute on function public.xp_distance_multiplier(text, numeric) from public, anon;
grant execute on function public.xp_distance_multiplier(text, numeric) to authenticated;

create or replace function public.xp_duration_multiplier(p_minutes int)
returns numeric
language sql
immutable
as $$
  select case
    when p_minutes < 15 then 0.5 when p_minutes < 30 then 1.0
    when p_minutes < 60 then 1.5 when p_minutes < 90 then 2.0
    else 2.5
  end;
$$;

revoke execute on function public.xp_duration_multiplier(int) from public, anon;
grant execute on function public.xp_duration_multiplier(int) to authenticated;

create or replace function public.xp_weight_loss_multiplier(p_kg numeric)
returns numeric
language sql
immutable
as $$
  select case
    when p_kg < 1 then 0.5 when p_kg < 3 then 1.0 when p_kg < 5 then 1.5
    when p_kg < 10 then 2.0 else 2.5
  end;
$$;

revoke execute on function public.xp_weight_loss_multiplier(numeric) from public, anon;
grant execute on function public.xp_weight_loss_multiplier(numeric) to authenticated;

-- Streak milestone XP for a given week number, or null if that week isn't
-- a milestone. 4/12/26/52 are the spec's original fixed values; every 26
-- weeks after that uses increment = 1,800 + 400*n (n = 1 at week 78, n = 2
-- at week 104, ...), cumulative — see the spec's "Gap found and fixed" note.
create or replace function public.xp_streak_milestone(p_week int)
returns int
language sql
immutable
as $$
  select case
    when p_week = 4 then 150
    when p_week = 12 then 500
    when p_week = 26 then 1200
    when p_week = 52 then 3000
    when p_week > 52 and p_week % 26 = 0 then
      3000 + (
        select sum(1800 + 400 * n)
        from generate_series(1, (p_week - 52) / 26) as n
      )
    else null
  end;
$$;

revoke execute on function public.xp_streak_milestone(int) from public, anon;
grant execute on function public.xp_streak_milestone(int) to authenticated;

create or replace function public.xp_challenge_placement(p_place int)
returns int
language sql
immutable
as $$
  select case p_place
    when 1 then 1000 when 2 then 700 when 3 then 500 when 4 then 350
    when 5 then 300 when 6 then 250 when 7 then 200 when 8 then 150
    when 9 then 120 when 10 then 100 else 0
  end;
$$;

revoke execute on function public.xp_challenge_placement(int) from public, anon;
grant execute on function public.xp_challenge_placement(int) to authenticated;

-- 5. The one function that actually writes XP. Deliberately NOT granted to
-- authenticated (or anyone) — it must only ever be reachable by being
-- called from inside another SECURITY DEFINER function it shares an owner
-- with (log_goal_progress etc. below), which works via ownership even
-- without a grant. A version of this callable directly by the client
-- would let anyone hand themselves arbitrary XP.
create or replace function public._award_xp(
  p_user_id uuid,
  p_amount int,
  p_category text,
  p_reason text,
  p_goal_id uuid default null,
  p_league_id uuid default null,
  p_streak_week int default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if p_amount <= 0 then
    return;
  end if;

  update public.profiles set xp = xp + p_amount where id = p_user_id;

  insert into public.xp_events (
    user_id, category, amount, reason, goal_id, league_id, streak_week
  ) values (
    p_user_id, p_category, p_amount, p_reason, p_goal_id, p_league_id, p_streak_week
  );
end;
$$;

revoke execute on function public._award_xp(
  uuid, int, text, text, uuid, uuid, int
) from public, anon, authenticated;

-- 6. Streak-milestone check, called from log_goal_progress right after a
-- check-in is logged (activity_check_ins is only ever written from there
-- now — see 0011/0012's "streak heatmap driven by goal completions" note,
-- so this is the one and only place a streak can advance). Recomputes the
-- current weekly streak the same way get_streak_summary does, awards any
-- newly-crossed milestone once, and resets the award flags when a streak
-- of exactly 1 shows a fresh run just started (the only way a continuous
-- weekly streak can be 1 again after having been higher is a break in
-- between — see the spec's award-once rule).
create or replace function public._check_streak_milestones(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_weekly int := 0;
  v_week_cursor date := date_trunc('week', current_date)::date;
  v_has_activity boolean;
  v_week int;
  v_xp int;
begin
  loop
    select exists(
      select 1 from public.activity_check_ins
      where user_id = p_user_id
        and logged_date >= v_week_cursor
        and logged_date < v_week_cursor + 7
    ) into v_has_activity;
    exit when not v_has_activity;
    v_weekly := v_weekly + 1;
    v_week_cursor := v_week_cursor - 7;
  end loop;

  if v_weekly = 1 then
    delete from public.streak_milestone_awards where user_id = p_user_id;
  end if;

  for v_week in
    select w from unnest(array[4, 12, 26]) as w
    where w <= v_weekly
    union all
    select w from generate_series(52, v_weekly, 26) as w
  loop
    if not exists (
      select 1 from public.streak_milestone_awards
      where user_id = p_user_id and milestone_week = v_week
    ) then
      insert into public.streak_milestone_awards (user_id, milestone_week)
      values (p_user_id, v_week);

      v_xp := public.xp_streak_milestone(v_week);
      if v_xp is not null then
        perform public._award_xp(
          p_user_id, v_xp, 'streak',
          v_week || '-week streak milestone', null, null, v_week
        );
      end if;
    end if;
  end loop;
end;
$$;

revoke execute on function public._check_streak_milestones(uuid) from public, anon, authenticated;

-- 7. log_goal_progress — same signature as 0020 (CREATE OR REPLACE stays a
-- true replace, not a new overload), now also awarding goal-completion XP
-- and checking streak milestones on every successful check-in.
--
-- Anti-spam per the spec: one shared daily XP slot per category (distance
-- vs duration — both distance-type and time-type goals draw from their own
-- single daily slot regardless of which of run/walk/cycle/swim it is), and
-- a minimum-plausible-duration check (elapsed time since the goal was
-- created must be physically consistent with the claimed distance/time —
-- an impossible claim just doesn't earn XP; the stake/completion itself
-- still goes through normally, same self-report trust level as everywhere
-- else in the app).
create or replace function public.log_goal_progress(
  p_goal_id uuid,
  p_proof_image_url text default null,
  p_strava_username text default null
)
returns public.goals
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_goal public.goals;
  v_category text;
  v_min_minutes numeric;
  v_elapsed_minutes numeric;
  v_plausible boolean;
  v_already_awarded_today boolean;
  v_xp int;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if p_proof_image_url is null or trim(p_proof_image_url) = '' then
    raise exception 'A Strava screenshot is required';
  end if;

  if p_strava_username is null or trim(p_strava_username) = '' then
    raise exception 'Strava username missing';
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

  insert into public.activity_check_ins (
    user_id, activity, logged_date, proof_image_url, strava_username
  )
  values (
    v_user_id, v_goal.distance_activity, current_date,
    p_proof_image_url, p_strava_username
  )
  on conflict (user_id, logged_date, activity) do update
    set proof_image_url = excluded.proof_image_url,
        strava_username = excluded.strava_username;

  -- Goal-completion XP (every successful log earns it — a weekly-cadence
  -- goal's each check-in is that week's "completion"; a once-cadence
  -- goal's single log is its only one).
  v_category := case v_goal.type when 'distance' then 'distance' else 'duration' end;
  v_elapsed_minutes := extract(epoch from (now() - v_goal.created_at)) / 60;

  if v_goal.type = 'distance' then
    v_min_minutes := greatest(2, v_goal.distance_km / (case v_goal.distance_activity
      when 'walk' then 8 when 'run' then 25 when 'cycle' then 60 when 'swim' then 6
      else 10 end) * 60);
  else
    v_min_minutes := v_goal.time_minutes;
  end if;
  v_plausible := v_elapsed_minutes >= v_min_minutes;

  select exists(
    select 1 from public.xp_events
    where user_id = v_user_id and category = v_category
      and created_at::date = current_date
  ) into v_already_awarded_today;

  if v_plausible and not v_already_awarded_today then
    v_xp := round(
      public.xp_stake_base(v_goal.stake_cents) * (case v_goal.type
        when 'distance' then public.xp_distance_multiplier(v_goal.distance_activity, v_goal.distance_km)
        else public.xp_duration_multiplier(v_goal.time_minutes)
      end)
    );
    perform public._award_xp(
      v_user_id, v_xp, v_category, 'Goal completion', p_goal_id
    );
  end if;

  perform public._check_streak_milestones(v_user_id);

  if v_goal.distance_cadence = 'once' then
    update public.profiles
      set wallet_balance_cents = wallet_balance_cents + v_goal.stake_cents
      where id = v_user_id;

    update public.goals
      set status = 'completed',
          completed_at = now(),
          proof_image_url = p_proof_image_url,
          strava_username = p_strava_username
      where id = p_goal_id
      returning * into v_goal;

    insert into public.wallet_transactions (user_id, type, amount_cents, status, goal_id, completed_at)
    values (v_user_id, 'goal_refund', v_goal.stake_cents, 'completed', p_goal_id, now());
  end if;

  return v_goal;
end;
$$;

revoke execute on function public.log_goal_progress(uuid, text, text) from public, anon;
grant execute on function public.log_goal_progress(uuid, text, text) to authenticated;

-- 8. complete_weight_loss_goal — same signature as 0013, now awarding
-- goal-completion XP too. No daily-category cap here (a weight-loss goal
-- can only ever complete once, and the minimum multi-day window below
-- already rules out same-day spam the way the distance/duration cap does).
create or replace function public.complete_weight_loss_goal(p_goal_id uuid)
returns public.goals
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_goal public.goals;
  v_elapsed_days numeric;
  v_xp int;
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

  insert into public.wallet_transactions (user_id, type, amount_cents, status, goal_id, completed_at)
  values (v_user_id, 'goal_refund', v_goal.stake_cents, 'completed', p_goal_id, now());

  -- Minimum multi-day window (spec: "weight-loss goals require a minimum
  -- multi-day window by nature of the goal type") — 3 days is a bare-floor
  -- sanity check, not a realistic timeline; easy to raise if it turns out
  -- too permissive.
  v_elapsed_days := extract(epoch from (now() - v_goal.created_at)) / 86400;
  if v_elapsed_days >= 3 then
    v_xp := round(
      public.xp_stake_base(v_goal.stake_cents)
        * public.xp_weight_loss_multiplier(v_goal.weight_loss_target_kg)
    );
    perform public._award_xp(v_user_id, v_xp, 'weight_loss', 'Goal completion', p_goal_id);
  end if;

  return v_goal;
end;
$$;

revoke execute on function public.complete_weight_loss_goal(uuid) from public, anon;
grant execute on function public.complete_weight_loss_goal(uuid) to authenticated;

-- 9. finalize_league — same signature as 0017, now also awarding Community
-- Challenge placement XP to the top 10 finishers (ranked exactly the way
-- the winner is already picked: everyone who completed all 30 days,
-- fastest total elapsed time first), gated on 10+ entrants per the spec's
-- min-field-size rule. Entrants who didn't finish all 30 days don't get
-- placement XP — there's no meaningful "place" to pay for a challenge they
-- didn't complete.
create or replace function public.finalize_league(p_league_id uuid)
returns public.leagues
language plpgsql
security definer set search_path = public
as $$
declare
  v_league public.leagues;
  v_winner uuid;
  v_entrant_count int;
  v_rank int;
  v_finisher record;
begin
  if not public.is_forgo_founder() then
    raise exception 'Only the founder can finalize a league';
  end if;

  select * into v_league from public.leagues where id = p_league_id for update;
  if not found then
    raise exception 'League not found';
  end if;

  if v_league.finalized_at is not null then
    raise exception 'League already finalized';
  end if;

  if now() < public.league_day_release_at(v_league.start_date, 31) then
    raise exception 'This league has not finished yet';
  end if;

  select e.user_id into v_winner
  from public.league_entries e
  where e.league_id = p_league_id
    and not exists (
      select 1 from generate_series(1, 30) as d(n)
      where not exists (
        select 1 from public.league_submissions s
        where s.league_id = p_league_id and s.user_id = e.user_id
          and s.day_number = d.n and s.completed
      )
    )
  order by (
    select sum(
      extract(epoch from (s.submitted_at - public.league_day_release_at(v_league.start_date, s.day_number)))
    )
    from public.league_submissions s
    where s.league_id = p_league_id and s.user_id = e.user_id and s.completed
  ) asc
  limit 1;

  if v_winner is not null then
    update public.profiles
      set wallet_balance_cents = wallet_balance_cents + v_league.prize_cents
      where id = v_winner;

    insert into public.wallet_transactions (user_id, type, amount_cents, status, league_id, completed_at)
    values (v_winner, 'league_prize', v_league.prize_cents, 'completed', p_league_id, now());
  end if;

  select count(*) into v_entrant_count
  from public.league_entries where league_id = p_league_id;

  if v_entrant_count >= 10 then
    v_rank := 0;
    for v_finisher in
      select e.user_id
      from public.league_entries e
      where e.league_id = p_league_id
        and not exists (
          select 1 from generate_series(1, 30) as d(n)
          where not exists (
            select 1 from public.league_submissions s
            where s.league_id = p_league_id and s.user_id = e.user_id
              and s.day_number = d.n and s.completed
          )
        )
      order by (
        select sum(
          extract(epoch from (s.submitted_at - public.league_day_release_at(v_league.start_date, s.day_number)))
        )
        from public.league_submissions s
        where s.league_id = p_league_id and s.user_id = e.user_id and s.completed
      ) asc
      limit 10
    loop
      v_rank := v_rank + 1;
      perform public._award_xp(
        v_finisher.user_id, public.xp_challenge_placement(v_rank), 'challenge',
        'League placement #' || v_rank, null, p_league_id
      );
    end loop;
  end if;

  update public.leagues
    set winner_user_id = v_winner, finalized_at = now()
    where id = p_league_id
    returning * into v_league;

  return v_league;
end;
$$;

revoke execute on function public.finalize_league(uuid) from public, anon;
grant execute on function public.finalize_league(uuid) to authenticated;
