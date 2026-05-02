-- ============================================================
-- SiE Core Schema — initial migration
-- ============================================================


-- ── Utility: auto-update updated_at ──────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ── profiles ─────────────────────────────────────────────────
create table public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  updated_at    timestamptz,
  username      text unique,
  full_name     text,
  avatar_url    text,
  total_xp      int     not null default 0,
  is_lab_member boolean not null default false
);

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

create policy "anyone can read profiles"
  on public.profiles for select
  using (true);

create policy "owner can update own profile"
  on public.profiles for update
  using (auth.uid() = id);


-- ── Auto-create profile on signup ────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, full_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url'
  );
  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ── branches ─────────────────────────────────────────────────
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
create table public.user_branches (
  id                    uuid        primary key default gen_random_uuid(),
  user_id               uuid        not null references public.profiles on delete cascade,
  branch_id             uuid        not null references public.branches  on delete cascade,
  level                 int         not null default 1 check (level >= 1),
  virtual_clients_count int         not null default 0,
  last_activity         timestamptz,
  updated_at            timestamptz,
  unique (user_id, branch_id)
);

create index idx_user_branches_user_id on public.user_branches (user_id);

create trigger trg_user_branches_updated_at
  before update on public.user_branches
  for each row execute function public.set_updated_at();

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
