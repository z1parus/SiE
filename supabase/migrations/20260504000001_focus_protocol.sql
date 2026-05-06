-- ── focus_sessions ────────────────────────────────────────────
create table public.focus_sessions (
  id               uuid        primary key default gen_random_uuid(),
  user_id          uuid        not null references public.profiles on delete cascade,
  duration_seconds int         not null,
  is_completed     boolean     not null default false,
  xp_gained        int         not null default 0,
  created_at       timestamptz not null default now()
);

create index idx_focus_sessions_user_id on public.focus_sessions (user_id);

alter table public.focus_sessions enable row level security;

create policy "owner can read own focus_sessions"
  on public.focus_sessions for select using (auth.uid() = user_id);

create policy "owner can insert own focus_sessions"
  on public.focus_sessions for insert with check (auth.uid() = user_id);


-- ── Achievement ───────────────────────────────────────────────
insert into public.achievements (slug, name, description, xp_reward, icon_emoji)
values (
  'deep_focus_initiated',
  'Deep Focus Initiated',
  'Завершена первая 25-минутная сессия глубокой концентрации.',
  50,
  '🎯'
);


-- ── Branch ────────────────────────────────────────────────────
insert into public.branches (slug, name, description)
values (
  'focus_protocol',
  'Focus Protocol',
  'Pomodoro-таймер для глубокой концентрации. 25 минут работы, 5 минут отдыха.'
)
on conflict (slug) do nothing;
