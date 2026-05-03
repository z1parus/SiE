-- ── habits ───────────────────────────────────────────────────
create table public.habits (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references public.profiles on delete cascade,
  title       text        not null,
  description text,
  color       text        not null default '#00C8FF',
  created_at  timestamptz not null default now()
);

alter table public.habits enable row level security;

create policy "owner can read own habits"
  on public.habits for select using (auth.uid() = user_id);
create policy "owner can insert own habits"
  on public.habits for insert with check (auth.uid() = user_id);
create policy "owner can update own habits"
  on public.habits for update using (auth.uid() = user_id);
create policy "owner can delete own habits"
  on public.habits for delete using (auth.uid() = user_id);


-- ── habit_logs ────────────────────────────────────────────────
create table public.habit_logs (
  id           uuid primary key default gen_random_uuid(),
  habit_id     uuid not null references public.habits on delete cascade,
  user_id      uuid not null references public.profiles on delete cascade,
  completed_at date not null default current_date,
  xp_awarded   int  not null default 50,
  unique (habit_id, completed_at)
);

create index idx_habit_logs_user_date
  on public.habit_logs (user_id, completed_at);

alter table public.habit_logs enable row level security;

create policy "owner can read own habit_logs"
  on public.habit_logs for select using (auth.uid() = user_id);
create policy "owner can insert own habit_logs"
  on public.habit_logs for insert with check (auth.uid() = user_id);
create policy "owner can delete own habit_logs"
  on public.habit_logs for delete using (auth.uid() = user_id);


-- ── Branch seed ───────────────────────────────────────────────
insert into public.branches (slug, name, description)
values (
  'habit_archive',
  'Habit Archive',
  'Система ежедневных привычек. Формируй дисциплину через повторение.'
)
on conflict (slug) do nothing;
