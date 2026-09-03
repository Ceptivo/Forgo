-- Forgo: wallet ledger entries for goal stakes/refunds, group image/bio,
-- and a member-editable group-settings RPC
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0012.

-- 1. Wallet ledger: a goal's stake and (if it completes) its refund now
-- show up as real transactions, not just a silent wallet_balance_cents
-- change — the type distinguishes direction (amount_cents itself always
-- stays a positive magnitude, same as topup), and goal_id lets the app
-- pull the goal's own title/deadline to build "Goal | Run 5km by ..." /
-- "Goal Achieved | Run 5km on ..." without duplicating that formatting
-- logic in SQL.
alter table public.wallet_transactions drop constraint if exists wallet_transactions_type_check;
alter table public.wallet_transactions
  add constraint wallet_transactions_type_check
  check (type in ('topup', 'goal_stake', 'goal_refund'));

alter table public.wallet_transactions
  add column if not exists goal_id uuid references public.goals (id) on delete set null;

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

  insert into public.wallet_transactions (user_id, type, amount_cents, status, goal_id, completed_at)
  values (v_user_id, 'goal_stake', p_stake_cents, 'completed', v_goal.id, now());

  return v_goal;
end;
$$;

revoke execute on function public.create_goal_with_stake(
  text, bigint, date, numeric, text, text, numeric, int
) from public, anon;
grant execute on function public.create_goal_with_stake(
  text, bigint, date, numeric, text, text, numeric, int
) to authenticated;

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

    insert into public.wallet_transactions (user_id, type, amount_cents, status, goal_id, completed_at)
    values (v_user_id, 'goal_refund', v_goal.stake_cents, 'completed', p_goal_id, now());
  end if;

  return v_goal;
end;
$$;

revoke execute on function public.log_goal_progress(uuid) from public, anon;
grant execute on function public.log_goal_progress(uuid) to authenticated;

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

  insert into public.wallet_transactions (user_id, type, amount_cents, status, goal_id, completed_at)
  values (v_user_id, 'goal_refund', v_goal.stake_cents, 'completed', p_goal_id, now());

  return v_goal;
end;
$$;

revoke execute on function public.complete_weight_loss_goal(uuid) from public, anon;
grant execute on function public.complete_weight_loss_goal(uuid) to authenticated;

-- 2. Group settings: an image, a short bio, and (below, in Flutter) a
-- page listing invite code + every goal round. Any member can edit —
-- same trust level as sending a message in the chat — enforced via
-- is_goal_group_member rather than restricting to created_by.
alter table public.goal_groups add column if not exists bio text;
alter table public.goal_groups add column if not exists image_url text;

create or replace function public.update_goal_group(
  p_group_id uuid,
  p_name text default null,
  p_bio text default null,
  p_image_url text default null
)
returns public.goal_groups
language plpgsql
security definer set search_path = public
as $$
declare
  v_group public.goal_groups;
begin
  if not public.is_goal_group_member(p_group_id) then
    raise exception 'Not a member of this group';
  end if;

  update public.goal_groups
    set name = coalesce(nullif(trim(p_name), ''), name),
        bio = coalesce(p_bio, bio),
        image_url = coalesce(p_image_url, image_url)
    where id = p_group_id
    returning * into v_group;

  return v_group;
end;
$$;

revoke execute on function public.update_goal_group(uuid, text, text, text) from public, anon;
grant execute on function public.update_goal_group(uuid, text, text, text) to authenticated;

-- Public bucket (same pattern as `avatars` in 0007_profile_extras.sql),
-- folder-per-group instead of folder-per-user, gated by group membership
-- rather than an exact auth.uid() match.
insert into storage.buckets (id, name, public)
values ('group_images', 'group_images', true)
on conflict (id) do nothing;

create policy "Group images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'group_images');

create policy "Members can upload their group's image"
  on storage.objects for insert
  with check (
    bucket_id = 'group_images'
    and public.is_goal_group_member(((storage.foldername(name))[1])::uuid)
  );

create policy "Members can update their group's image"
  on storage.objects for update
  using (
    bucket_id = 'group_images'
    and public.is_goal_group_member(((storage.foldername(name))[1])::uuid)
  );

create policy "Members can delete their group's image"
  on storage.objects for delete
  using (
    bucket_id = 'group_images'
    and public.is_goal_group_member(((storage.foldername(name))[1])::uuid)
  );
