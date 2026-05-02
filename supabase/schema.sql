-- ============================================================
-- SiE Core Schema — reference copy (canonical source: migrations/)
-- ============================================================

-- ── profiles ─────────────────────────────────────────────────
-- One row per auth.users entry; XP tracks global progress.
create table public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  updated_at    timestamptz,
  username      text unique,
  full_name     text,
  avatar_url    text,
  total_xp      int  not null default 0,
  is_lab_member boolean not null default false
);

alter table public.profiles enable row level security;

create policy "anyone can read profiles"
  on public.profiles for select
  using (true);

create policy "owner can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- ── branches ─────────────────────────────────────────────────
-- Product verticals (habit-tracker, finance, etc.).
create table public.branches (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  description text,
  icon_url    text
);

alter table public.branches enable row level security;

create policy "anyone can read branches"
  on public.branches for select
  using (true);

-- ── user_branches ─────────────────────────────────────────────
-- Per-user progress inside a branch (level, virtual clients).
create table public.user_branches (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles on delete cascade,
  branch_id             uuid not null references public.branches on delete cascade,
  level                 int  not null default 1,
  virtual_clients_count int  not null default 0,
  last_activity         timestamptz,
  unique (user_id, branch_id)
);

alter table public.user_branches enable row level security;

create policy "owner can read own user_branches"
  on public.user_branches for select
  using (auth.uid() = user_id);

create policy "owner can insert own user_branches"
  on public.user_branches for insert
  with check (auth.uid() = user_id);

create policy "owner can update own user_branches"
  on public.user_branches for update
  using (auth.uid() = user_id);

create policy "owner can delete own user_branches"
  on public.user_branches for delete
  using (auth.uid() = user_id);
