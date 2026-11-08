-- Create profiles table for synced user data.
-- Each user gets exactly one row, keyed by the user's auth.uid.
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text not null default '',
  email         text,
  avatar_base64 text,
  status        text not null default 'Focus operative',
  lifetime_fokus_tasks   integer not null default 0,
  timer_customization    jsonb,
  blue_light_settings    jsonb,
  progress_data          jsonb,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

-- Automatically update updated_at on row modification.
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_profiles_updated on public.profiles;
create trigger on_profiles_updated
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ── Row Level Security ──

alter table public.profiles enable row level security;

-- Drop any potentially insecure select policies from the database
drop policy if exists "Users can read all profiles" on public.profiles;
drop policy if exists "Authenticated users can read all profiles" on public.profiles;
drop policy if exists "Users can read own profile" on public.profiles;

-- Users can only read their own profile (tasks, brain dumps, settings).
create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

-- Users can insert their own profile (sign-up).
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Users can update their own profile.
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- Create a B-Tree index on lowercase of email for fast friend email searches
create index if not exists idx_profiles_email_lower on public.profiles (lower(email));

-- Create a public leaderboard view exposing only public columns.
create or replace view public.public_leaderboard as
  select 
    id, 
    name, 
    status, 
    avatar_base64, 
    lifetime_fokus_tasks,
    coalesce((progress_data ->> 'local_user_points')::integer, 0) as total_points,
    coalesce((progress_data ->> 'local_user_fokus_minutes')::integer, 0) as fokus_minutes,
    email
  from public.profiles
  where auth.uid() is not null;

-- ── Auto-create profile on sign-up ──

create or replace function public.handle_new_user()
returns trigger as $$
declare
  username text;
begin
  username := coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1), '');
  if username = '' then
    username := 'User';
  end if;

  insert into public.profiles (id, name, email)
  values (
    new.id,
    username,
    new.email
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
