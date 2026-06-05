-- ── habit_routines ────────────────────────────────────────────────────────────
-- Stores morning/evening routine definitions. One row per user per type.

create table public.habit_routines (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references public.profiles on delete cascade,
  routine_type text        not null check (routine_type in ('morning', 'evening')),
  created_at   timestamptz not null default now(),
  unique (user_id, routine_type)
);

alter table public.habit_routines enable row level security;

create policy "owner can read own routines"
  on public.habit_routines for select
  using (auth.uid() = user_id);

create policy "owner can insert own routines"
  on public.habit_routines for insert
  with check (auth.uid() = user_id);

create policy "owner can update own routines"
  on public.habit_routines for update
  using (auth.uid() = user_id);

create policy "owner can delete own routines"
  on public.habit_routines for delete
  using (auth.uid() = user_id);

create index idx_habit_routines_user on public.habit_routines (user_id);

-- ── habit_routine_members ─────────────────────────────────────────────────────
-- Ordered list of habits belonging to each routine.

create table public.habit_routine_members (
  id         uuid    primary key default gen_random_uuid(),
  routine_id uuid    not null references public.habit_routines on delete cascade,
  habit_id   uuid    not null references public.habits on delete cascade,
  position   integer not null default 0,
  unique (routine_id, habit_id)
);

alter table public.habit_routine_members enable row level security;

-- RLS via join: only the owner of the parent routine can access members.
create policy "owner can read own routine members"
  on public.habit_routine_members for select
  using (
    exists (
      select 1 from public.habit_routines r
      where r.id = routine_id and r.user_id = auth.uid()
    )
  );

create policy "owner can insert own routine members"
  on public.habit_routine_members for insert
  with check (
    exists (
      select 1 from public.habit_routines r
      where r.id = routine_id and r.user_id = auth.uid()
    )
  );

create policy "owner can update own routine members"
  on public.habit_routine_members for update
  using (
    exists (
      select 1 from public.habit_routines r
      where r.id = routine_id and r.user_id = auth.uid()
    )
  );

create policy "owner can delete own routine members"
  on public.habit_routine_members for delete
  using (
    exists (
      select 1 from public.habit_routines r
      where r.id = routine_id and r.user_id = auth.uid()
    )
  );

create index idx_routine_members_routine on public.habit_routine_members (routine_id, position);
