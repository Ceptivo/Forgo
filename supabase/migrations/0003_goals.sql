-- Forgo: goal creation + staking
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually.

-- Security fix for the *already-applied* 0001_profiles.sql: its
-- "Users can update own profile" RLS policy is a row-level check
-- (auth.uid() = id) with no column restriction, which means any signed-in
-- user could currently set their own wallet_balance_cents to anything via
-- a normal client update — RLS can't express "this column, not that one",
-- so it needs a column-level privilege revoke on top. This has to run
-- whether or not you've built anything on top of the wallet yet.
revoke update (wallet_balance_cents) on public.profiles from authenticated;
-- profiles.wallet_balance_cents can now only change via SECURITY DEFINER
-- functions owned by a privileged role (credit_wallet_from_transaction,
-- create_goal_with_stake below) — never directly from the app.

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('run', 'weight_loss')),
  status text not null default 'active'
    check (status in ('active', 'completed', 'failed', 'cancelled')),
  stake_cents bigint not null check (stake_cents > 0),

  -- Run goal fields
  run_distance_km numeric(6, 2),
  run_cadence text check (run_cadence in ('once', 'weekly')),

  -- Weight-loss goal fields
  weight_loss_target_kg numeric(5, 2),

  -- Required for a one-off run goal and for weight-loss; null for a
  -- recurring/weekly run goal, which has no fixed end date in v1.
  deadline date,

  created_at timestamptz not null default now(),

  constraint goals_fields_match_type check (
    (
      type = 'run'
      and run_distance_km is not null
      and run_cadence is not null
      and weight_loss_target_kg is null
      and (run_cadence = 'once') = (deadline is not null)
    )
    or (
      type = 'weight_loss'
      and weight_loss_target_kg is not null
      and run_distance_km is null
      and run_cadence is null
      and deadline is not null
    )
  )
);

create index if not exists goals_user_id_idx on public.goals (user_id);

alter table public.goals enable row level security;

create policy "Users can view own goals"
  on public.goals for select
  using (auth.uid() = user_id);

-- No insert/update policy for the authenticated role: goals are only ever
-- created via create_goal_with_stake below (which atomically deducts the
-- stake in the same transaction) and resolved later by verification logic
-- that doesn't exist yet — never by a direct client write.

-- Atomically deducts a stake from the caller's own wallet and creates the
-- goal, so a goal can never exist without its stake having actually been
-- taken (or vice versa). Runs as the caller (auth.uid()), not on behalf of
-- an arbitrary user_id — unlike credit_wallet_from_transaction, this is
-- called directly by the app (via `supabase.rpc(...)`), not an Edge
-- Function, since it's the user spending their own money on their own
-- goal rather than an external payment gateway confirming one.
create or replace function public.create_goal_with_stake(
  p_type text,
  p_stake_cents bigint,
  p_deadline date,
  p_run_distance_km numeric default null,
  p_run_cadence text default null,
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
    run_distance_km, run_cadence, weight_loss_target_kg
  ) values (
    v_user_id, p_type, p_stake_cents, p_deadline,
    p_run_distance_km, p_run_cadence, p_weight_loss_target_kg
  )
  returning * into v_goal;

  return v_goal;
end;
$$;

revoke execute on function public.create_goal_with_stake(
  text, bigint, date, numeric, text, numeric
) from public, anon;
grant execute on function public.create_goal_with_stake(
  text, bigint, date, numeric, text, numeric
) to authenticated;
