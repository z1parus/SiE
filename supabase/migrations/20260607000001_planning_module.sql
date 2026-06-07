-- ── Goals ─────────────────────────────────────────────────────────────────
create table public.goals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles(id) on delete cascade not null,
  name        text not null,
  description text,
  deadline    timestamptz,
  priority    int  not null default 2,        -- 1 low · 2 medium · 3 high · 4 critical
  status      text not null default 'active', -- active/completed/failed/frozen
  color_hex   text not null default '#5AADA0',
  progress    float not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ── Sub-goals (self-referential tree) ─────────────────────────────────────
create table public.sub_goals (
  id                 uuid primary key default gen_random_uuid(),
  goal_id            uuid references public.goals(id) on delete cascade not null,
  parent_sub_goal_id uuid references public.sub_goals(id) on delete cascade,
  name               text not null,
  is_completed       bool not null default false,
  order_index        int  not null default 0,
  created_at         timestamptz not null default now()
);

-- ── Planning tasks ─────────────────────────────────────────────────────────
create table public.planning_tasks (
  id           uuid primary key default gen_random_uuid(),
  sub_goal_id  uuid references public.sub_goals(id) on delete cascade not null,
  user_id      uuid references public.profiles(id) on delete cascade not null,
  name         text not null,
  weight       int  not null default 1,  -- 1/3/5
  is_completed bool not null default false,
  completed_at timestamptz,
  due_date     timestamptz,
  created_at   timestamptz not null default now()
);

-- ── Milestones ─────────────────────────────────────────────────────────────
create table public.milestones (
  id           uuid primary key default gen_random_uuid(),
  goal_id      uuid references public.goals(id) on delete cascade not null,
  name         text not null,
  target_date  timestamptz,
  is_completed bool not null default false,
  created_at   timestamptz not null default now()
);

-- ── Goal ↔ Habit links ─────────────────────────────────────────────────────
create table public.goal_habit_links (
  id         uuid primary key default gen_random_uuid(),
  goal_id    uuid references public.goals(id) on delete cascade not null,
  habit_id   uuid not null,
  created_at timestamptz not null default now(),
  unique(goal_id, habit_id)
);

-- ── RLS ───────────────────────────────────────────────────────────────────
alter table public.goals            enable row level security;
alter table public.sub_goals        enable row level security;
alter table public.planning_tasks   enable row level security;
alter table public.milestones       enable row level security;
alter table public.goal_habit_links enable row level security;

create policy "own goals"
  on public.goals for all using (auth.uid() = user_id);
create policy "own sub_goals"
  on public.sub_goals for all
  using (exists (select 1 from public.goals where id = sub_goals.goal_id and user_id = auth.uid()));
create policy "own planning_tasks"
  on public.planning_tasks for all using (auth.uid() = user_id);
create policy "own milestones"
  on public.milestones for all
  using (exists (select 1 from public.goals where id = milestones.goal_id and user_id = auth.uid()));
create policy "own goal_habit_links"
  on public.goal_habit_links for all
  using (exists (select 1 from public.goals where id = goal_habit_links.goal_id and user_id = auth.uid()));
