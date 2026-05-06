-- ── Achievement ───────────────────────────────────────────────
insert into public.achievements (slug, name, description, xp_reward, icon_emoji)
values (
  'data_analyst',
  'Data Analyst',
  'Открыт Центр Аналитики при наличии не менее 5 записей в логах.',
  75,
  '📊'
);

-- ── Branch ────────────────────────────────────────────────────
insert into public.branches (slug, name, description)
values (
  'progress_hub',
  'Progress Hub',
  'Аналитика активности: тепловая карта, графики роста XP и статистика фокуса.'
)
on conflict (slug) do nothing;
