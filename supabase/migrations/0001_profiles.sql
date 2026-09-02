-- Forgo: profiles table + 18+ enforcement + RLS
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. The Flutter app only holds the public
-- anon key, which cannot run DDL, so this file must be applied manually.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text not null default '',
  date_of_birth date not null,
  wallet_balance_cents bigint not null default 0,
  created_at timestamptz not null default now(),

  -- Server-side backstop for the 18+ requirement enforced client-side at
  -- signup. now() is fine here: profiles are created once, at signup time.
  constraint profiles_minimum_age check (
    date_of_birth <= (current_date - interval '18 years')
  ),
  constraint profiles_wallet_balance_non_negative check (
    wallet_balance_cents >= 0
  )
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Auto-create a profile row when a new auth user signs up, reading the
-- full_name/date_of_birth passed as signUp() metadata from the Flutter app.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, date_of_birth)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    (new.raw_user_meta_data ->> 'date_of_birth')::date
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
