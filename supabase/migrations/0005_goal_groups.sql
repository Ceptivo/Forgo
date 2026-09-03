-- Forgo: Group Chat Goals
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0004.
--
-- Shape: a goal_group is a persistent membership + chat container. Members
-- start "rounds" (goal_group_goals) — one shared goal at a time, same
-- stake for every member who joins it. Each member's stake/outcome for a
-- round is its own row (goal_group_stakes) so the group's leaderboard can
-- be computed by aggregating across every round a member has taken part
-- in. Outcomes are self-reported for now, same trust model as individual
-- goals in 0003_goals.sql — there's no automated verification anywhere in
-- the app yet.

create table if not exists public.goal_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 60),
  invite_code text not null,
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create unique index if not exists goal_groups_invite_code_idx
  on public.goal_groups (invite_code);

create table if not exists public.goal_group_members (
  group_id uuid not null references public.goal_groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index if not exists goal_group_members_user_id_idx
  on public.goal_group_members (user_id);

-- One "round" of a shared goal within a group — same shape as an
-- individual goal in public.goals, minus user_id (each member's stake is
-- its own row in goal_group_stakes below).
create table if not exists public.goal_group_goals (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.goal_groups (id) on delete cascade,
  started_by uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('distance', 'weight_loss')),
  status text not null default 'active' check (status in ('active', 'resolved')),
  stake_cents bigint not null check (stake_cents > 0),

  distance_km numeric(6, 2),
  distance_cadence text check (distance_cadence in ('once', 'weekly')),
  distance_activity text check (distance_activity in ('run', 'walk', 'cycle', 'swim')),

  weight_loss_target_kg numeric(5, 2),

  deadline date,

  created_at timestamptz not null default now(),
  resolved_at timestamptz,

  constraint goal_group_goals_fields_match_type check (
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
  )
);

-- Only one round in flight per group at a time — start_goal_group_round
-- checks this too, but a partial unique index makes it impossible to
-- violate even under concurrent calls.
create unique index if not exists goal_group_goals_one_active_per_group_idx
  on public.goal_group_goals (group_id)
  where status = 'active';

create index if not exists goal_group_goals_group_id_idx
  on public.goal_group_goals (group_id);

create table if not exists public.goal_group_stakes (
  goal_group_goal_id uuid not null references public.goal_group_goals (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  stake_cents bigint not null check (stake_cents > 0),
  outcome text not null default 'pending' check (outcome in ('pending', 'completed', 'failed')),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (goal_group_goal_id, user_id)
);

create index if not exists goal_group_stakes_user_id_idx
  on public.goal_group_stakes (user_id);

create table if not exists public.goal_group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.goal_groups (id) on delete cascade,
  -- Null sender_id = a system message (join/win/loss) attributed to
  -- nobody in particular; who it's *about* is sender_id on win/loss rows
  -- instead, since those are always about the member reporting their own
  -- outcome.
  sender_id uuid references auth.users (id) on delete set null,
  kind text not null default 'text' check (kind in ('text', 'system_join', 'system_win', 'system_loss')),
  body text not null,
  amount_cents bigint,
  created_at timestamptz not null default now()
);

create index if not exists goal_group_messages_group_id_created_at_idx
  on public.goal_group_messages (group_id, created_at);

alter table public.goal_groups enable row level security;
alter table public.goal_group_members enable row level security;
alter table public.goal_group_goals enable row level security;
alter table public.goal_group_stakes enable row level security;
alter table public.goal_group_messages enable row level security;

create or replace function public.is_goal_group_member(p_group_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.goal_group_members
    where group_id = p_group_id and user_id = auth.uid()
  );
$$;

create policy "Members can view their groups"
  on public.goal_groups for select
  using (public.is_goal_group_member(id));

create policy "Members can view group membership"
  on public.goal_group_members for select
  using (public.is_goal_group_member(group_id));

create policy "Members can view group rounds"
  on public.goal_group_goals for select
  using (public.is_goal_group_member(group_id));

create policy "Members can view group stakes"
  on public.goal_group_stakes for select
  using (
    public.is_goal_group_member(
      (select group_id from public.goal_group_goals where id = goal_group_goal_id)
    )
  );

create policy "Members can view group messages"
  on public.goal_group_messages for select
  using (public.is_goal_group_member(group_id));

create policy "Members can send group messages"
  on public.goal_group_messages for insert
  with check (
    sender_id = auth.uid()
    and kind = 'text'
    and public.is_goal_group_member(group_id)
  );

-- No insert/update policy on goal_groups, goal_group_members,
-- goal_group_goals, or goal_group_stakes for the authenticated role —
-- every mutation to those goes through a SECURITY DEFINER function below,
-- the same pattern as create_goal_with_stake in 0003_goals.sql, so wallet
-- debits/credits stay atomic with the row changes that justify them.

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
    v_code := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));
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

create or replace function public.join_goal_group_by_code(p_invite_code text)
returns public.goal_groups
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_group public.goal_groups;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_group
    from public.goal_groups
    where invite_code = upper(trim(p_invite_code));

  if not found then
    raise exception 'Invalid invite code';
  end if;

  insert into public.goal_group_members (group_id, user_id)
  values (v_group.id, v_user_id)
  on conflict (group_id, user_id) do nothing;

  insert into public.goal_group_messages (group_id, sender_id, kind, body)
  values (v_group.id, v_user_id, 'system_join', 'Joined the group');

  return v_group;
end;
$$;

-- Starts a new round and immediately stakes the caller into it (the
-- caller is always the first member in) — deducts from their wallet in
-- the same transaction as the round + stake rows so a round can never
-- exist without its starter's stake actually being taken.
create or replace function public.start_goal_group_round(
  p_group_id uuid,
  p_type text,
  p_stake_cents bigint,
  p_deadline date,
  p_distance_km numeric default null,
  p_distance_cadence text default null,
  p_distance_activity text default null,
  p_weight_loss_target_kg numeric default null
)
returns public.goal_group_goals
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_balance bigint;
  v_round public.goal_group_goals;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_goal_group_member(p_group_id) then
    raise exception 'Not a member of this group';
  end if;

  if p_stake_cents <= 0 then
    raise exception 'Stake must be greater than zero';
  end if;

  if exists (
    select 1 from public.goal_group_goals
    where group_id = p_group_id and status = 'active'
  ) then
    raise exception 'This group already has an active goal';
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

  insert into public.goal_group_goals (
    group_id, started_by, type, stake_cents, deadline,
    distance_km, distance_cadence, distance_activity, weight_loss_target_kg
  ) values (
    p_group_id, v_user_id, p_type, p_stake_cents, p_deadline,
    p_distance_km, p_distance_cadence, p_distance_activity, p_weight_loss_target_kg
  )
  returning * into v_round;

  insert into public.goal_group_stakes (goal_group_goal_id, user_id, stake_cents)
  values (v_round.id, v_user_id, p_stake_cents);

  insert into public.goal_group_messages (group_id, sender_id, kind, body)
  values (p_group_id, v_user_id, 'text', 'Started a new group goal — join in!');

  return v_round;
end;
$$;

-- A member stakes into the group's current active round, at that round's
-- fixed stake amount (everyone stakes the same).
create or replace function public.join_goal_group_round(p_round_id uuid)
returns public.goal_group_stakes
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_group_id uuid;
  v_stake_cents bigint;
  v_status text;
  v_balance bigint;
  v_stake public.goal_group_stakes;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select group_id, stake_cents, status
    into v_group_id, v_stake_cents, v_status
    from public.goal_group_goals
    where id = p_round_id;

  if not found then
    raise exception 'Goal not found';
  end if;

  if not public.is_goal_group_member(v_group_id) then
    raise exception 'Not a member of this group';
  end if;

  if v_status <> 'active' then
    raise exception 'This goal is no longer accepting stakes';
  end if;

  if exists (
    select 1 from public.goal_group_stakes
    where goal_group_goal_id = p_round_id and user_id = v_user_id
  ) then
    raise exception 'Already staked in this goal';
  end if;

  select wallet_balance_cents into v_balance
    from public.profiles
    where id = v_user_id
    for update;

  if v_balance < v_stake_cents then
    raise exception 'Insufficient wallet balance';
  end if;

  update public.profiles
    set wallet_balance_cents = wallet_balance_cents - v_stake_cents
    where id = v_user_id;

  insert into public.goal_group_stakes (goal_group_goal_id, user_id, stake_cents)
  values (p_round_id, v_user_id, v_stake_cents)
  returning * into v_stake;

  insert into public.goal_group_messages (group_id, sender_id, kind, body)
  values (v_group_id, v_user_id, 'text', 'Joined the group goal');

  return v_stake;
end;
$$;

-- Self-reports the caller's own outcome for a round they staked into.
-- Completed: their stake is credited straight back to their wallet.
-- Failed: the stake is forfeited (stays out of their wallet — the "goes
-- to charity instead" language used elsewhere in the app; there's no
-- payout integration yet, so this is a ledger record, not a transfer).
-- Either way, a system chat message makes the outcome visible to the
-- rest of the group. When every member's stake in the round is resolved,
-- the round itself is marked resolved so a new one can start.
create or replace function public.report_goal_group_outcome(
  p_round_id uuid,
  p_completed boolean
)
returns public.goal_group_stakes
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_group_id uuid;
  v_stake_cents bigint;
  v_outcome text;
  v_stake public.goal_group_stakes;
  v_pending_count int;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select goal_group_goals.group_id, goal_group_stakes.stake_cents, goal_group_stakes.outcome
    into v_group_id, v_stake_cents, v_outcome
    from public.goal_group_stakes
    join public.goal_group_goals on goal_group_goals.id = goal_group_stakes.goal_group_goal_id
    where goal_group_stakes.goal_group_goal_id = p_round_id
      and goal_group_stakes.user_id = v_user_id
    for update of goal_group_stakes;

  if not found then
    raise exception 'You have not staked in this goal';
  end if;

  if v_outcome <> 'pending' then
    raise exception 'You already reported an outcome for this goal';
  end if;

  update public.goal_group_stakes
    set outcome = case when p_completed then 'completed' else 'failed' end,
        resolved_at = now()
    where goal_group_goal_id = p_round_id and user_id = v_user_id
    returning * into v_stake;

  if p_completed then
    update public.profiles
      set wallet_balance_cents = wallet_balance_cents + v_stake_cents
      where id = v_user_id;

    insert into public.goal_group_messages (group_id, sender_id, kind, body, amount_cents)
    values (v_group_id, v_user_id, 'system_win', 'Hit the goal', v_stake_cents);
  else
    insert into public.goal_group_messages (group_id, sender_id, kind, body, amount_cents)
    values (v_group_id, v_user_id, 'system_loss', 'Missed the goal', v_stake_cents);
  end if;

  select count(*) into v_pending_count
    from public.goal_group_stakes
    where goal_group_goal_id = p_round_id and outcome = 'pending';

  if v_pending_count = 0 then
    update public.goal_group_goals
      set status = 'resolved', resolved_at = now()
      where id = p_round_id;
  end if;

  return v_stake;
end;
$$;

revoke execute on function public.create_goal_group(text) from public, anon;
grant execute on function public.create_goal_group(text) to authenticated;

revoke execute on function public.join_goal_group_by_code(text) from public, anon;
grant execute on function public.join_goal_group_by_code(text) to authenticated;

revoke execute on function public.start_goal_group_round(
  uuid, text, bigint, date, numeric, text, text, numeric
) from public, anon;
grant execute on function public.start_goal_group_round(
  uuid, text, bigint, date, numeric, text, text, numeric
) to authenticated;

revoke execute on function public.join_goal_group_round(uuid) from public, anon;
grant execute on function public.join_goal_group_round(uuid) to authenticated;

revoke execute on function public.report_goal_group_outcome(uuid, boolean) from public, anon;
grant execute on function public.report_goal_group_outcome(uuid, boolean) to authenticated;

-- profiles' RLS only lets a user read their own row (0001_profiles.sql),
-- so group members can't otherwise see each other's names at all. Rather
-- than widen that policy (which would also expose email, date_of_birth,
-- wallet_balance_cents to group-mates), this returns just id + full_name,
-- and only for members of a group the caller is themselves in.
create or replace function public.get_goal_group_member_names(p_group_id uuid)
returns table (user_id uuid, full_name text)
language sql
security definer set search_path = public
stable
as $$
  select profiles.id, profiles.full_name
  from public.profiles
  join public.goal_group_members on goal_group_members.user_id = profiles.id
  where goal_group_members.group_id = p_group_id
    and public.is_goal_group_member(p_group_id);
$$;

revoke execute on function public.get_goal_group_member_names(uuid) from public, anon;
grant execute on function public.get_goal_group_member_names(uuid) to authenticated;

-- Realtime: let clients subscribe to new chat messages via
-- supabase_flutter's `.stream()` (Postgres logical replication), same as
-- any other realtime table.
alter publication supabase_realtime add table public.goal_group_messages;
