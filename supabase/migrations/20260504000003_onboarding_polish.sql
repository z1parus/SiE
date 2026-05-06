-- ── Welcome flag ─────────────────────────────────────────────
alter table public.profiles
  add column if not exists has_seen_welcome boolean not null default false;

-- ── Achievement ───────────────────────────────────────────────
insert into public.achievements (slug, name, description, xp_reward, icon_emoji)
values (
  'first_habit_created',
  'Первый Протокол Дисциплины',
  'Создана первая привычка в архиве. Начало положено.',
  25,
  '🌱'
)
on conflict (slug) do nothing;
