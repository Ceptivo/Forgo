-- Forgo: Strava screenshot as proof when self-reporting a distance/time
-- goal (Run/Walk/Cycle/Swim) — no automated reading of the screenshot,
-- same self-report trust level as everywhere else in the app; this just
-- attaches evidence and a timestamp to what the user already tells us.
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Run it after 0001-0019.

-- 1. Storage: a proof photo per check-in (weekly goals log many times, so
-- this can't be a single upsert-in-place file like avatars/group images —
-- each upload gets its own unique filename). Public read (consistent with
-- every other bucket in this app), folder-per-user write.
insert into storage.buckets (id, name, public)
values ('goal_proofs', 'goal_proofs', true)
on conflict (id) do nothing;

create policy "Goal proofs are publicly readable"
  on storage.objects for select
  using (bucket_id = 'goal_proofs');

create policy "Users can upload their own goal proofs"
  on storage.objects for insert
  with check (
    bucket_id = 'goal_proofs'
    and ((storage.foldername(name))[1])::uuid = auth.uid()
  );

-- 2. Columns. goals gets the "completed goal" snapshot (only meaningful
-- for a one-off goal, which actually reaches 'completed'); activity_check_ins
-- gets its own copy since a recurring weekly goal logs many times and
-- never itself "completes" — each week's proof belongs to that week's
-- check-in, not the goal.
alter table public.goals
  add column if not exists completed_at timestamptz,
  add column if not exists proof_image_url text,
  add column if not exists strava_username text;

alter table public.activity_check_ins
  add column if not exists proof_image_url text,
  add column if not exists strava_username text;

-- 3. log_goal_progress now requires proof + a Strava username on every
-- call (adding trailing optional params keeps this a true replace, not a
-- new overload, so every existing grant/revoke still applies). The
-- client already blocks reaching this without both — this is the
-- server-side backstop.
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
