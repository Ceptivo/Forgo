-- Forgo: "No Turning Back" — a 30-day founder-run competitive league inside
-- the Forgo Community Group.
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Run it after 0001-0016.
--
-- Scope for this first version (see the app's own feature notes — this is
-- flagged for legal review before a real-money league is actually run,
-- given entry fee + cash prize + winner determination under the National
-- Gambling Act):
--   - Verification is self-report only (tap "I did it" / "I missed it"),
--     same as every other goal in the app today. No photo, no AI check —
--     that's a separate, much larger feature to build later.
--   - A league's entry fee/prize amounts and its 30 daily goals are all
--     entered through an in-app founder-only "Create League" form, not
--     seeded by hand via SQL like community goals/charities/feature votes.
--   - No automatic monthly scheduling or prize rollover yet — the founder
--     creates each league themselves, and finalizes it (paying the winner)
--     with an explicit action once day 30's window has closed.

-- 1. Founder check — reuses the Forgo Community Group's created_by (see
-- 0015_community.sql: the first-ever signed-up user), rather than adding
-- a whole roles/permissions system for a single admin-only feature.
create or replace function public.is_forgo_founder()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.goal_groups
    where id = '00000000-0000-0000-0000-000000000001'
      and created_by = auth.uid()
  );
$$;

revoke execute on function public.is_forgo_founder() from public, anon;
grant execute on function public.is_forgo_founder() to authenticated;

-- 2. Schema. A day's release time is always computed the same way (day 1
-- releases on start_date at 04:00 SAST, day 2 the next day at 04:00 SAST,
-- and so on) — South Africa has no daylight saving, so SAST is a fixed
-- UTC+2 and 04:00 SAST is always 02:00 UTC.
create or replace function public.league_day_release_at(p_start_date date, p_day_number int)
returns timestamptz
language sql
immutable
as $$
  select ((p_start_date + (p_day_number - 1)) || ' 02:00:00+00')::timestamptz;
$$;

create table if not exists public.leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 80),
  entry_fee_cents bigint not null check (entry_fee_cents >= 0),
  prize_cents bigint not null check (prize_cents >= 0),
  start_date date not null,
  created_by uuid not null references auth.users (id),
  winner_user_id uuid references auth.users (id),
  finalized_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.league_days (
  league_id uuid not null references public.leagues (id) on delete cascade,
  day_number int not null check (day_number between 1 and 30),
  title text not null check (char_length(trim(title)) between 1 and 120),
  description text not null check (char_length(trim(description)) between 1 and 500),
  primary key (league_id, day_number)
);

create table if not exists public.league_entries (
  league_id uuid not null references public.leagues (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (league_id, user_id)
);

create table if not exists public.league_submissions (
  league_id uuid not null,
  user_id uuid not null,
  day_number int not null,
  completed boolean not null,
  submitted_at timestamptz not null default now(),
  primary key (league_id, user_id, day_number),
  foreign key (league_id, user_id)
    references public.league_entries (league_id, user_id) on delete cascade
);

create index if not exists league_days_league_id_idx on public.league_days (league_id);
create index if not exists league_entries_league_id_idx on public.league_entries (league_id);
create index if not exists league_submissions_league_id_idx on public.league_submissions (league_id);

-- 3. Wallet ledger: joining a league shows as a "-R" line (like a goal
-- stake) and winning shows as a "+R" line (like a goal refund).
alter table public.wallet_transactions drop constraint if exists wallet_transactions_type_check;
alter table public.wallet_transactions
  add constraint wallet_transactions_type_check
  check (type in ('topup', 'goal_stake', 'goal_refund', 'league_entry', 'league_prize'));

alter table public.wallet_transactions
  add column if not exists league_id uuid references public.leagues (id) on delete set null;

-- 4. RLS. Everything is public read for any signed-in user (this is a
-- community-wide competition, not a private group) — except league_days,
-- where a future day's title/description stays hidden until its own
-- release time, so the daily drop is actually a drop. All writes go
-- through the RPCs below (owned by a role that bypasses RLS, same as
-- every other SECURITY DEFINER function in this app) — there are
-- deliberately no insert/update policies on any of these tables.
alter table public.leagues enable row level security;
create policy "Signed-in users can view leagues"
  on public.leagues for select using (auth.uid() is not null);

alter table public.league_days enable row level security;
create policy "Only released days are visible"
  on public.league_days for select
  using (
    auth.uid() is not null
    and now() >= public.league_day_release_at(
      (select start_date from public.leagues where id = league_id), day_number
    )
  );

alter table public.league_entries enable row level security;
create policy "Signed-in users can view league entries"
  on public.league_entries for select using (auth.uid() is not null);

alter table public.league_submissions enable row level security;
create policy "Signed-in users can view league submissions"
  on public.league_submissions for select using (auth.uid() is not null);

-- 5. RPCs.

-- Founder-only: create a league and its 30 daily goals in one call — the
-- in-app "Create League" form submits all of it together.
create or replace function public.create_league(
  p_name text,
  p_entry_fee_cents bigint,
  p_prize_cents bigint,
  p_start_date date,
  p_days jsonb -- array of exactly 30 {day_number, title, description}
)
returns public.leagues
language plpgsql
security definer set search_path = public
as $$
declare
  v_league public.leagues;
  v_day jsonb;
begin
  if not public.is_forgo_founder() then
    raise exception 'Only the founder can create a league';
  end if;

  if jsonb_array_length(p_days) <> 30 then
    raise exception 'A league needs exactly 30 days';
  end if;

  insert into public.leagues (name, entry_fee_cents, prize_cents, start_date, created_by)
  values (p_name, p_entry_fee_cents, p_prize_cents, p_start_date, auth.uid())
  returning * into v_league;

  for v_day in select * from jsonb_array_elements(p_days)
  loop
    insert into public.league_days (league_id, day_number, title, description)
    values (
      v_league.id,
      (v_day->>'day_number')::int,
      v_day->>'title',
      v_day->>'description'
    );
  end loop;

  return v_league;
end;
$$;

revoke execute on function public.create_league(text, bigint, bigint, date, jsonb) from public, anon;
grant execute on function public.create_league(text, bigint, bigint, date, jsonb) to authenticated;

-- Joining pays the entry fee immediately (non-refundable, even on later
-- elimination — it's an admin/gate cost, not prize funding, per the
-- feature's own design). Only open before day 1 releases.
create or replace function public.join_league(p_league_id uuid)
returns public.league_entries
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_league public.leagues;
  v_balance bigint;
  v_entry public.league_entries;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_league from public.leagues where id = p_league_id;
  if not found then
    raise exception 'League not found';
  end if;

  if now() >= public.league_day_release_at(v_league.start_date, 1) then
    raise exception 'This league has already started';
  end if;

  if exists (
    select 1 from public.league_entries
    where league_id = p_league_id and user_id = v_user_id
  ) then
    raise exception 'Already joined this league';
  end if;

  if v_league.entry_fee_cents > 0 then
    select wallet_balance_cents into v_balance
      from public.profiles where id = v_user_id for update;

    if v_balance is null then
      raise exception 'Profile not found';
    end if;

    if v_balance < v_league.entry_fee_cents then
      raise exception 'Insufficient wallet balance';
    end if;

    update public.profiles
      set wallet_balance_cents = wallet_balance_cents - v_league.entry_fee_cents
      where id = v_user_id;

    insert into public.wallet_transactions (user_id, type, amount_cents, status, league_id, completed_at)
    values (v_user_id, 'league_entry', v_league.entry_fee_cents, 'completed', p_league_id, now());
  end if;

  insert into public.league_entries (league_id, user_id)
  values (p_league_id, v_user_id)
  returning * into v_entry;

  return v_entry;
end;
$$;

revoke execute on function public.join_league(uuid) from public, anon;
grant execute on function public.join_league(uuid) to authenticated;

-- Self-report for one day, only while that day's window is open (from its
-- own 04:00 SAST release to the next day's). One submission per day —
-- missing the window entirely (never submitting) is what elimination is
-- based on, computed on read rather than written anywhere.
create or replace function public.submit_league_day(
  p_league_id uuid,
  p_day_number int,
  p_completed boolean
)
returns public.league_submissions
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_league public.leagues;
  v_submission public.league_submissions;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from public.league_entries
    where league_id = p_league_id and user_id = v_user_id
  ) then
    raise exception 'You have not joined this league';
  end if;

  select * into v_league from public.leagues where id = p_league_id;
  if not found then
    raise exception 'League not found';
  end if;

  if now() < public.league_day_release_at(v_league.start_date, p_day_number) then
    raise exception 'This day has not been released yet';
  end if;
  if now() >= public.league_day_release_at(v_league.start_date, p_day_number + 1) then
    raise exception 'The window for this day has closed';
  end if;

  if exists (
    select 1 from public.league_submissions
    where league_id = p_league_id and user_id = v_user_id and day_number = p_day_number
  ) then
    raise exception 'Already submitted for this day';
  end if;

  insert into public.league_submissions (league_id, user_id, day_number, completed, submitted_at)
  values (p_league_id, v_user_id, p_day_number, p_completed, now())
  returning * into v_submission;

  return v_submission;
end;
$$;

revoke execute on function public.submit_league_day(uuid, int, boolean) from public, anon;
grant execute on function public.submit_league_day(uuid, int, boolean) to authenticated;

-- Founder-only: pays out the winner and locks the league. The winner is
-- computed here, authoritatively and independently of anything the app
-- shows client-side — real money moves off the back of this query, so it
-- is never trusted from client input. Winner = among everyone who
-- completed all 30 days, whoever has the lowest total elapsed time
-- between each day's release and their submission for it. If nobody
-- completed all 30 days, the league is finalized with no winner and no
-- payout (the prize simply isn't spent this round — there's no
-- rollover-to-next-month automation yet, see the feature notes).
create or replace function public.finalize_league(p_league_id uuid)
returns public.leagues
language plpgsql
security definer set search_path = public
as $$
declare
  v_league public.leagues;
  v_winner uuid;
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

  update public.leagues
    set winner_user_id = v_winner, finalized_at = now()
    where id = p_league_id
    returning * into v_league;

  return v_league;
end;
$$;

revoke execute on function public.finalize_league(uuid) from public, anon;
grant execute on function public.finalize_league(uuid) to authenticated;
