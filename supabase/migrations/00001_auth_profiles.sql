-- 00001_auth_profiles.sql
-- Creates the profiles table, RLS policies, and auto-creation trigger
-- This is the first migration for the Ouest app
-- Note: Idempotent — safe to re-run if objects already exist

-- ============================================================
-- 1. PROFILES TABLE
-- ============================================================
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text not null,
    full_name text,
    handle text unique,
    avatar_url text,
    nationality text,
    bio text,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

-- Index for looking up users by handle (used in search/invite)
create index if not exists idx_profiles_handle on public.profiles(handle);

-- ============================================================
-- 2. ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;

-- Drop and recreate policies to ensure they match our expected definitions
do $$
begin
    -- Select policy
    if not exists (
        select 1 from pg_policies
        where tablename = 'profiles' and policyname = 'Profiles are viewable by authenticated users'
    ) then
        create policy "Profiles are viewable by authenticated users"
            on public.profiles for select to authenticated using (true);
    end if;

    -- Insert policy
    if not exists (
        select 1 from pg_policies
        where tablename = 'profiles' and policyname = 'Users can insert their own profile'
    ) then
        create policy "Users can insert their own profile"
            on public.profiles for insert to authenticated with check (auth.uid() = id);
    end if;

    -- Update policy
    if not exists (
        select 1 from pg_policies
        where tablename = 'profiles' and policyname = 'Users can update their own profile'
    ) then
        create policy "Users can update their own profile"
            on public.profiles for update to authenticated
            using (auth.uid() = id) with check (auth.uid() = id);
    end if;
end $$;

-- ============================================================
-- 3. AUTO-CREATE PROFILE ON SIGNUP
-- ============================================================

-- Function that creates a profile row when a new user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, email, full_name)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data ->> 'full_name', '')
    );
    return new;
end;
$$;

-- Trigger that fires after a new user is created in auth.users
create or replace trigger on_auth_user_created
    after insert on auth.users
    for each row
    execute function public.handle_new_user();

-- ============================================================
-- 4. AUTO-UPDATE updated_at TIMESTAMP
-- ============================================================

-- Function to auto-set updated_at on row update
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create or replace trigger profiles_updated_at
    before update on public.profiles
    for each row
    execute function public.set_updated_at();
