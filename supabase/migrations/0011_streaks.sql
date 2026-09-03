-- Forgo: activity check-ins + streaks
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0010.
--
-- A lightweight, separate-from-staked-goals "I did this today" log —
-- there's still no automated verification anywhere in the app, so this
-- is self-reported the same way group-goal outcomes are. It powers the
-- home screen's weekly streak row, the streak heatmap, and the
-- 12/26/52-week badges shown on a profile.

create table if not exists public.activity_check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  activity text not null check (activity in ('run', 'walk', 'cycle', 'swim')),
  logged_date date not null,
  created_at timestamptz not null default now(),
  unique (user_id, logged_date, activity)
);

create index if not exists activity_check_ins_user_id_date_idx
  on public.activity_check_ins (user_id, logged_date);

alter table public.activity_check_ins enable row level security;

create policy "Users can view own check-ins"
  on public.activity_check_ins for select
  using (auth.uid() = user_id);

-- No money moves here, unlike goals — a direct RLS-scoped insert/delete
-- is enough, no SECURITY DEFINER function needed for writes.
create policy "Users can log own check-ins"
  on public.activity_check_ins for insert
  with check (auth.uid() = user_id);

create policy "Users can remove own check-ins"
  on public.activity_check_ins for delete
  using (auth.uid() = user_id);

-- Everything the home screen, heatmap, and profile badges need in one
-- call: current daily streak, current weekly streak, the longest weekly
-- streak ever reached (badges are permanent once earned, so they're
-- keyed off this rather than the current streak, which can drop), and
-- the last 7 days' activity for the home screen's day-icon row.
-- SECURITY DEFINER + broadly grantable: none of this is more sensitive
-- than the goal/follow counts already exposed via get_public_profile_stats.
create or replace function public.get_streak_summary(p_user_id uuid)
returns table (
  current_daily_streak int,
  current_weekly_streak int,
  longest_weekly_streak int,
  last_7_days jsonb
)
language plpgsql
security definer set search_path = public
stable
as $$
declare
  v_daily int := 0;
  v_weekly int := 0;
  v_longest int := 0;
  v_streak int := 0;
  v_cursor date := current_date;
  v_week_cursor date;
  v_has_activity boolean;
  v_prev_week date;
  v_week date;
  v_weeks date[];
begin
  loop
    select exists(
      select 1 from public.activity_check_ins
      where user_id = p_user_id and logged_date = v_cursor
    ) into v_has_activity;
    exit when not v_has_activity;
    v_daily := v_daily + 1;
    v_cursor := v_cursor - 1;
  end loop;

  v_week_cursor := date_trunc('week', current_date)::date;
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

  select array_agg(distinct date_trunc('week', logged_date)::date order by date_trunc('week', logged_date)::date)
    into v_weeks
    from public.activity_check_ins
    where user_id = p_user_id;

  v_prev_week := null;
  if v_weeks is not null then
    foreach v_week in array v_weeks loop
      if v_prev_week is not null and v_week = v_prev_week + 7 then
        v_streak := v_streak + 1;
      else
        v_streak := 1;
      end if;
      if v_streak > v_longest then
        v_longest := v_streak;
      end if;
      v_prev_week := v_week;
    end loop;
  end if;

  return query
    select
      v_daily,
      v_weekly,
      v_longest,
      (
        select coalesce(jsonb_agg(jsonb_build_object('date', s.d, 'activity', (
          select activity from public.activity_check_ins
          where user_id = p_user_id and logged_date = s.d
          order by created_at desc
          limit 1
        )) order by s.d), '[]'::jsonb)
        from (select current_date - (6 - i) as d from generate_series(0, 6) as i) s
      );
end;
$$;

revoke execute on function public.get_streak_summary(uuid) from public, anon;
grant execute on function public.get_streak_summary(uuid) to authenticated;
