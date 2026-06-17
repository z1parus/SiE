-- ── Редизайн узоров профиля ───────────────────────────────────
-- Старые узоры (Полигоны / Изо / Нейронные нити / Точки) имели заливку,
-- перекрывающую цвет фона, и не вписывались в стиль приложения. Заменяем на
-- 5 штриховых узоров (без заливки): Топографика, Тактическая сетка, Радар,
-- Меридианы сферы, Гильош. Все бесплатны (price_dp = 0).
--
-- Идемпотентно: можно применять повторно.

-- 1. Снять оснащение у пользователей со старыми узорами.
update public.profiles
   set equipped_pattern_id = null
 where equipped_pattern_id in (
   select id from public.profile_patterns
    where slug in ('low_poly','iso_grid','isometric','neural_threads','dot_matrix')
 );

-- 2. Убрать старые узоры из инвентаря.
delete from public.user_inventory
 where asset_type = 'profile_pattern'
   and asset_id in (
     select id from public.profile_patterns
      where slug in ('low_poly','iso_grid','isometric','neural_threads','dot_matrix')
   );

-- 3. Удалить старые узоры из каталога.
delete from public.profile_patterns
 where slug in ('low_poly','iso_grid','isometric','neural_threads','dot_matrix');

-- 4. Новые штриховые узоры (все бесплатны).
insert into public.profile_patterns (slug, name, rarity, style_config, price_dp) values
  ('topo',             'Топографика',      'common',    '{"pattern_slug":"topo","opacity":0.5}',             0),
  ('hud_grid',         'Тактическая сетка','rare',       '{"pattern_slug":"hud_grid","opacity":0.5}',         0),
  ('radar',            'Радар',            'epic',       '{"pattern_slug":"radar","opacity":0.55}',           0),
  ('sphere_meridians', 'Меридианы сферы',  'epic',       '{"pattern_slug":"sphere_meridians","opacity":0.5}', 0),
  ('guilloche',        'Гильош',           'legendary',  '{"pattern_slug":"guilloche","opacity":0.5}',        0)
on conflict (slug) do update
  set name         = excluded.name,
      rarity       = excluded.rarity,
      style_config = excluded.style_config,
      price_dp     = excluded.price_dp;

-- 5. Выдать стартовый узор (Топографика) всем — чтобы в каталоге был
--    оснащаемый узор «из коробки».
insert into public.user_inventory (user_id, asset_type, asset_id)
select p.id, 'profile_pattern', pat.id
  from public.profiles p
  cross join public.profile_patterns pat
 where pat.slug = 'topo'
on conflict (user_id, asset_type, asset_id) do nothing;
