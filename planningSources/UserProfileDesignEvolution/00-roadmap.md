# User Profile Design Evolution — Roadmap

> Эволюция дизайна экранов **личного** и **публичного** профилей SiE.
> Текущая активная задача — **полный редизайн узоров фона профиля**
> (см. [`01-pattern-redesign.md`](01-pattern-redesign.md)).

---

## Принципы

1. **Опора на стиль приложения.** Золотой акцент (`SieColors.accent` ≈ `#C8A84B`),
   тёмная/светлая темы, тактический язык (PERSONNEL FILE / OPERATIVE / MISSION
   MEDALS), золотая дыхательная сфера. Только токены `SieColors` / `SieMotion`,
   без хардкод-цветов.
2. **Слоистая карточка профиля.** `ProfileHeroCard` = `база (цвет/градиент фона)`
   → `узор (штрихи)` → `лёгкий скрим` → `контент`.
3. **Узор не перекрывает фон.** Узоры — только тонкие линии/штрихи, без заливки;
   выбранный пользователем цвет фона остаётся виден и доминирует.
4. **Единая точка рендера.** Узор везде рисуется через общие
   `ProfilePatternLayer` (карточка) и `ProfilePatternThumb` (сетки магазина/
   облика) — экраны не дублируют логику.
5. **Reduce-motion.** Все анимации гасятся в статичный кадр при выключенной
   анимации ОС.

---

## Состояние профильных экранов (контекст, уже реализовано)

- **`ProfileHeroCard`** (`sie_core`) — общая верхняя карточка для личного и
  публичного профиля: кольцо прогресса уровня вокруг аватара, кокарда «LVL N»,
  XP-бар, чипы, кэш аватара, слоистый фон.
- **Личный профиль** — hero, полоса статов (Уровень/XP/DP), быстрые действия
  (Прогресс / База знаний / Облик), ачивки, медали.
- **Публичный профиль** — хедер (назад + имя), hero с фоном/узором владельца,
  соц-кнопки с состояниями, статы, ачивки, медали.
- **Облик / Интерфейс-Хаб** — таб «УЗОРЫ» (выбор/покупка) с live-превью.
- Инфраструктура узоров: `AssetType.profilePattern`, таблица `profile_patterns`,
  `profiles.equipped_pattern_id`, инвентарь, трансляция узора чужого профиля
  (включая лидерборд) — всё на месте и переиспользуется.

---

## Активный этап

| # | Документ | Суть |
|---|----------|------|
| 1 | [`01-pattern-redesign.md`](01-pattern-redesign.md) | **Редизайн узоров:** удалить старые (заливка, не в стиле), сделать 5 новых **штриховых** узоров, проброс во все экраны, чистка дублей/миграций |

---

## Карта затрагиваемого кода

| Что | Файл |
|---|---|
| Рендер узора (карточка) | `packages/sie_core/lib/src/widgets/profile_pattern_layer.dart` |
| Слоистая карточка | `packages/sie_core/lib/src/widgets/profile_hero_card.dart` |
| Модель ассета | `packages/sie_core/lib/src/models/cosmetic_asset.dart` |
| Каталог/инвентарь | `.../providers/customization_provider.dart`, `.../providers/inventory_provider.dart` |
| Экран личного профиля | `apps/central_hub/lib/screens/profile_screen.dart` |
| Экран публичного профиля | `apps/central_hub/lib/screens/public_profile_screen.dart` |
| Облик | `apps/central_hub/lib/screens/customization_screen.dart` |
| Магазин | `apps/central_hub/lib/screens/interface_hub_screen.dart` |
| Каталог в БД | `supabase/migrations/*_profile_patterns*.sql`, `supabase/schema.sql` |
