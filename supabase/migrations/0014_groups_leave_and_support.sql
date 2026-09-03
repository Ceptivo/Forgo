-- Forgo: leave-group, bug reports, feature suggestions + voting, and
-- charities we support
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as the earlier migrations, the app
-- only holds the anon key and can't run DDL itself, so this needs to be
-- applied manually. Run it after 0001-0013.

-- 1. Leaving a group — no money/stake implications (existing stakes stay
-- as historical rows either way), so this is a plain membership delete,
-- same SECURITY DEFINER pattern as everything else that writes to
-- goal_group_members.
create or replace function public.leave_goal_group(p_group_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.goal_group_members
  where group_id = p_group_id and user_id = v_user_id;
end;
$$;

revoke execute on function public.leave_goal_group(uuid) from public, anon;
grant execute on function public.leave_goal_group(uuid) to authenticated;

-- 2. Bug reports and feature suggestions — a single table since they're
-- the same shape (a title, a message, who sent it), just tagged by kind.
-- A user can see their own past submissions; nobody else's — a plain
-- RLS insert/select is enough, no money or cross-user access involved.
create table if not exists public.feedback_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('bug', 'feature')),
  title text not null check (char_length(trim(title)) between 1 and 120),
  description text not null check (char_length(trim(description)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists feedback_items_user_id_idx on public.feedback_items (user_id);

alter table public.feedback_items enable row level security;

create policy "Users can view their own feedback"
  on public.feedback_items for select
  using (auth.uid() = user_id);

create policy "Users can submit feedback"
  on public.feedback_items for insert
  with check (auth.uid() = user_id);

-- 3. Feature voting — a short, developer-curated shortlist (added by
-- hand via SQL, the same way this migration itself is applied; there's
-- no in-app admin role/UI) that users vote on, one active vote each.
-- Votes are counted through get_feature_candidates rather than exposed
-- as raw rows, so a user can't see who voted for what.
create table if not exists public.feature_candidates (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  created_at timestamptz not null default now()
);

alter table public.feature_candidates enable row level security;

create policy "Signed-in users can view feature candidates"
  on public.feature_candidates for select
  using (auth.uid() is not null);

create table if not exists public.feature_votes (
  user_id uuid primary key references auth.users (id) on delete cascade,
  candidate_id uuid not null references public.feature_candidates (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.feature_votes enable row level security;

create policy "Users can view their own vote"
  on public.feature_votes for select
  using (auth.uid() = user_id);

-- No insert/update policy — voting goes through cast_feature_vote so a
-- user always has at most one vote (switching candidates moves it,
-- rather than adding a second row).
create or replace function public.cast_feature_vote(p_candidate_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.feature_votes (user_id, candidate_id)
  values (auth.uid(), p_candidate_id)
  on conflict (user_id)
  do update set candidate_id = excluded.candidate_id, created_at = now();
end;
$$;

revoke execute on function public.cast_feature_vote(uuid) from public, anon;
grant execute on function public.cast_feature_vote(uuid) to authenticated;

create or replace function public.get_feature_candidates()
returns table (
  id uuid,
  title text,
  description text,
  vote_count bigint,
  my_vote boolean
)
language sql
security definer set search_path = public
stable
as $$
  select
    fc.id,
    fc.title,
    fc.description,
    (select count(*) from public.feature_votes where candidate_id = fc.id),
    exists (
      select 1 from public.feature_votes
      where candidate_id = fc.id and user_id = auth.uid()
    )
  from public.feature_candidates fc
  order by fc.created_at;
$$;

revoke execute on function public.get_feature_candidates() from public, anon;
grant execute on function public.get_feature_candidates() to authenticated;

-- A starter shortlist so the vote screen isn't empty — replace/add to
-- these with your own real candidates whenever; there's no in-app way
-- to manage them, just SQL:
--   insert into public.feature_candidates (title, description)
--   values ('Your idea', 'A sentence describing it.');
do $$
begin
  if not exists (select 1 from public.feature_candidates) then
    insert into public.feature_candidates (title, description) values
      ('Apple Pay / Google Pay top-ups', 'Top up your wallet without needing a card.'),
      ('Push notifications', 'A nudge when a deadline is close, or someone challenges your group.'),
      ('Dark mode', 'A dark theme alongside the current light one.');
  end if;
end $$;

-- 4. Charities Forgo supports — public read, no seed data (add your real
-- partners via SQL, same as feature_candidates):
--   insert into public.charities (name, description)
--   values ('Charity name', 'What they do.');
create table if not exists public.charities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null,
  created_at timestamptz not null default now()
);

alter table public.charities enable row level security;

create policy "Anyone signed in can view charities"
  on public.charities for select
  using (auth.uid() is not null);
