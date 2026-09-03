-- Forgo: follow other users, public profile stats, and consent-based
-- group invites
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0005.
--
-- Lets a user search for and follow other users, see their own and
-- others' follower/following/completed-goals counts, and invite a
-- followed friend into a group from 0005_goal_groups.sql — as an invite
-- the friend has to accept, never an instant add, since a group's goals
-- carry real money stakes.

create table if not exists public.user_follows (
  follower_id uuid not null references auth.users (id) on delete cascade,
  followee_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  constraint user_follows_no_self_follow check (follower_id <> followee_id)
);

create index if not exists user_follows_followee_id_idx
  on public.user_follows (followee_id);

alter table public.user_follows enable row level security;

-- A user can see who they follow and who follows them (both sides of
-- their own relationships), not arbitrary other users' follow graphs.
create policy "Users can view their own follow relationships"
  on public.user_follows for select
  using (auth.uid() = follower_id or auth.uid() = followee_id);

create policy "Users can follow others"
  on public.user_follows for insert
  with check (auth.uid() = follower_id);

create policy "Users can unfollow"
  on public.user_follows for delete
  using (auth.uid() = follower_id);

-- profiles' RLS (0001_profiles.sql) only lets a user read their own row,
-- so finding people to follow needs a narrow, SECURITY DEFINER search
-- that returns just id + full_name — never email, DOB, or wallet balance.
create or replace function public.search_profiles(p_query text)
returns table (user_id uuid, full_name text)
language sql
security definer set search_path = public
stable
as $$
  select id, full_name
  from public.profiles
  where id <> auth.uid()
    and full_name ilike '%' || trim(p_query) || '%'
  order by full_name
  limit 20;
$$;

revoke execute on function public.search_profiles(text) from public, anon;
grant execute on function public.search_profiles(text) to authenticated;

-- Same reasoning as search_profiles: user_follows alone has no names
-- (profiles' RLS wouldn't let a plain PostgREST embed read them), so the
-- "who do I follow" list needs its own narrow SECURITY DEFINER lookup.
create or replace function public.get_following()
returns table (user_id uuid, full_name text)
language sql
security definer set search_path = public
stable
as $$
  select profiles.id, profiles.full_name
  from public.user_follows
  join public.profiles on profiles.id = user_follows.followee_id
  where user_follows.follower_id = auth.uid()
  order by profiles.full_name;
$$;

revoke execute on function public.get_following() from public, anon;
grant execute on function public.get_following() to authenticated;

-- Everything a profile card needs about a user (their own, or someone
-- else's) in one call: display name, follower/following counts, how many
-- individual goals they've completed, and whether the caller already
-- follows them. SECURITY DEFINER because follower/following counts and
-- the completed-goals count both need to read rows (goals, user_follows
-- from the other side) that plain RLS wouldn't expose to the caller.
create or replace function public.get_public_profile_stats(p_user_id uuid)
returns table (
  full_name text,
  follower_count int,
  following_count int,
  completed_goals_count int,
  is_following boolean
)
language sql
security definer set search_path = public
stable
as $$
  select
    profiles.full_name,
    (select count(*) from public.user_follows where followee_id = p_user_id)::int,
    (select count(*) from public.user_follows where follower_id = p_user_id)::int,
    (select count(*) from public.goals where user_id = p_user_id and status = 'completed')::int,
    exists (
      select 1 from public.user_follows
      where follower_id = auth.uid() and followee_id = p_user_id
    )
  from public.profiles
  where profiles.id = p_user_id;
$$;

revoke execute on function public.get_public_profile_stats(uuid) from public, anon;
grant execute on function public.get_public_profile_stats(uuid) to authenticated;

-- Group invites: a member proposes adding a followed friend, the friend
-- has to accept before they're actually in the group (and able to see/
-- stake in its money-carrying goals) — never an instant add.
create table if not exists public.goal_group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.goal_groups (id) on delete cascade,
  invited_by uuid not null references auth.users (id) on delete cascade,
  invitee_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

-- Only one live invite per (group, invitee) at a time — a re-invite after
-- a decline is still allowed since the old row is no longer 'pending'.
create unique index if not exists goal_group_invites_one_pending_idx
  on public.goal_group_invites (group_id, invitee_id)
  where status = 'pending';

create index if not exists goal_group_invites_invitee_id_idx
  on public.goal_group_invites (invitee_id);

alter table public.goal_group_invites enable row level security;

create policy "Participants can view their group invites"
  on public.goal_group_invites for select
  using (auth.uid() = invitee_id or auth.uid() = invited_by);

-- No insert/update policy for the authenticated role — invites are only
-- ever created/resolved via invite_to_goal_group and
-- respond_to_goal_group_invite below, so membership can never be granted
-- without the invitee explicitly accepting.

-- An invitee isn't a group member yet, so the existing "Members can view
-- their groups" policy (0005_goal_groups.sql) wouldn't let them see even
-- the group's name on their invite card — this adds that one case.
create policy "Invitees can view groups they're invited to"
  on public.goal_groups for select
  using (
    exists (
      select 1 from public.goal_group_invites
      where goal_group_invites.group_id = goal_groups.id
        and goal_group_invites.invitee_id = auth.uid()
        and goal_group_invites.status = 'pending'
    )
  );

create or replace function public.invite_to_goal_group(
  p_group_id uuid,
  p_friend_user_id uuid
)
returns public.goal_group_invites
language plpgsql
security definer set search_path = public
as $$
declare
  v_invite public.goal_group_invites;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_goal_group_member(p_group_id) then
    raise exception 'Not a member of this group';
  end if;

  if exists (
    select 1 from public.goal_group_members
    where group_id = p_group_id and user_id = p_friend_user_id
  ) then
    raise exception 'Already a member of this group';
  end if;

  if not exists (
    select 1 from public.user_follows
    where follower_id = auth.uid() and followee_id = p_friend_user_id
  ) then
    raise exception 'You can only invite people you follow';
  end if;

  if exists (
    select 1 from public.goal_group_invites
    where group_id = p_group_id and invitee_id = p_friend_user_id and status = 'pending'
  ) then
    raise exception 'Already invited — waiting on their response';
  end if;

  insert into public.goal_group_invites (group_id, invited_by, invitee_id)
  values (p_group_id, auth.uid(), p_friend_user_id)
  returning * into v_invite;

  return v_invite;
end;
$$;

create or replace function public.respond_to_goal_group_invite(
  p_invite_id uuid,
  p_accept boolean
)
returns public.goal_group_invites
language plpgsql
security definer set search_path = public
as $$
declare
  v_invite public.goal_group_invites;
begin
  select * into v_invite
    from public.goal_group_invites
    where id = p_invite_id
    for update;

  if not found then
    raise exception 'Invite not found';
  end if;

  if v_invite.invitee_id <> auth.uid() then
    raise exception 'Not your invite to respond to';
  end if;

  if v_invite.status <> 'pending' then
    raise exception 'Already responded to this invite';
  end if;

  update public.goal_group_invites
    set status = case when p_accept then 'accepted' else 'declined' end,
        responded_at = now()
    where id = p_invite_id
    returning * into v_invite;

  if p_accept then
    insert into public.goal_group_members (group_id, user_id)
    values (v_invite.group_id, v_invite.invitee_id)
    on conflict (group_id, user_id) do nothing;

    insert into public.goal_group_messages (group_id, sender_id, kind, body)
    values (v_invite.group_id, v_invite.invitee_id, 'system_join', 'Joined the group');
  end if;

  return v_invite;
end;
$$;

revoke execute on function public.invite_to_goal_group(uuid, uuid) from public, anon;
grant execute on function public.invite_to_goal_group(uuid, uuid) to authenticated;

revoke execute on function public.respond_to_goal_group_invite(uuid, boolean) from public, anon;
grant execute on function public.respond_to_goal_group_invite(uuid, boolean) to authenticated;

-- Realtime: invitees see new invites land without a manual refresh.
alter publication supabase_realtime add table public.goal_group_invites;
