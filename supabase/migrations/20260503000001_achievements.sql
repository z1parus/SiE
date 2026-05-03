-- ── increment_xp RPC ─────────────────────────────────────────
create or replace function public.increment_xp(p_user_id uuid, p_amount int)
returns void
language sql
security definer set search_path = public
as $$
  update public.profiles
  set total_xp = total_xp + p_amount
  where id = p_user_id;
$$;


-- ── achievements ─────────────────────────────────────────────
create table public.achievements (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  description text,
  xp_reward   int  not null default 0
);

alter table public.achievements enable row level security;

create policy "anyone can read achievements"
  on public.achievements for select using (true);


-- ── user_achievements ────────────────────────────────────────
create table public.user_achievements (
  id             uuid        primary key default gen_random_uuid(),
  user_id        uuid        not null references public.profiles on delete cascade,
  achievement_id uuid        not null references public.achievements on delete cascade,
  earned_at      timestamptz not null default now(),
  unique (user_id, achievement_id)
);

create index idx_user_achievements_user_id on public.user_achievements (user_id);

alter table public.user_achievements enable row level security;

create policy "owner can read own achievements"
  on public.user_achievements for select using (auth.uid() = user_id);

create policy "owner can insert own achievements"
  on public.user_achievements for insert with check (auth.uid() = user_id);


-- ── Seeds ────────────────────────────────────────────────────
insert into public.achievements (slug, name, description, xp_reward)
values (
  'first_breath',
  'Первый вдох корпорации',
  'Завершена первая сессия дыхательных практик по методу Вима Хофа.',
  50
);

insert into public.branches (slug, name, description)
values (
  'breathing_practices',
  'Breathing Practices',
  'Дыхательные практики по методу Вима Хофа. Контроль тела через дыхание.'
)
on conflict (slug) do nothing;
