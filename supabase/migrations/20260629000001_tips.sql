-- ─────────────────────────────────────────────────────────────
-- Tips — daily hint banners shown on Operations screen
-- ─────────────────────────────────────────────────────────────

create table if not exists public.tips (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  description text not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table public.tips enable row level security;

-- Any authenticated user can read active tips
create policy "authenticated can read tips"
  on public.tips for select
  to authenticated
  using (true);

-- Only admins can create / update / delete
create policy "admin can insert tips"
  on public.tips for insert
  to authenticated
  with check (public.is_admin());

create policy "admin can update tips"
  on public.tips for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "admin can delete tips"
  on public.tips for delete
  to authenticated
  using (public.is_admin());

-- ── Seed ──────────────────────────────────────────────────────
insert into public.tips (title, description, is_active) values
  ('Виджеты на рабочем столе',
   'Вы можете установить виджеты SiE на главный экран смартфона — быстрый доступ к дыханию, фокусу, привычкам и миссиям.',
   true),
  ('Совместные цели',
   'Пригласите оперативника в свою миссию — работайте над задачами вместе в реальном времени на Tactical Map.',
   true),
  ('Дыхательные практики',
   'Метод Вима Хофа доступен прямо в приложении — 3 минуты дыхания снижают стресс и повышают концентрацию.',
   true),
  ('Стрик-бонусы',
   'Поддерживайте серию выполнения привычек 7 дней для множителя x1.5 и 30 дней для x2.0 к прогрессу целей.',
   true),
  ('Еженедельный обзор',
   'Проводите ревью каждую неделю — это формирует стрик обзоров и помогает не терять фокус на главных целях.',
   true)
on conflict do nothing;