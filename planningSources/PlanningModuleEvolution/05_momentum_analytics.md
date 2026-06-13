# Этап 5 — Импульс и аналитика темпа

## Описание

Сегодня `GoalStatsScreen` показывает только **снимок** (сколько задач выполнено сейчас). Нет
**истории прогресса во времени**, а значит невозможно ответить на главные вопросы достижения целей:
«С какой скоростью я двигаюсь?», «Успею ли к дедлайну?», «Когда реально закончу при текущем темпе?».
Этот этап вводит **исторические снимки прогресса** и строит на них аналитику: график прогресса,
скорость (velocity), **прогноз даты завершения** и burndown относительно дедлайна. Это превращает
`isGoalFatigued` (грубый булев флаг) в полноценную приборную панель темпа.

## Пользовательский сценарий

1. Пользователь открывает статистику цели → новая секция **«Импульс»**:
   - График прогресса за время (линия 0→100%), с отметкой дедлайна.
   - «**Темп:** +12% за последние 7 дней».
   - «**Прогноз:** при текущем темпе финиш ~24 июля (на 3 дня позже дедлайна)» — с цветовой
     индикацией (зелёный — успеваешь, янтарный — впритык, красный — не успеваешь).
   - «**Burndown:** идеальная линия vs фактическая» — видно отставание/опережение.
2. На карточке цели в списке — мини-индикатор импульса (стрелка ↗/→/↘ + цвет), мгновенно
   показывающий «двигается/стоит/тонет».
3. В War Room (этап 1) сводка дня может включать «1 цель теряет темп» с переходом к ней.

## Логика и поведение

### Сбор истории (снимки прогресса)
- Новая таблица `goal_progress_snapshots`: `goalId`, `progress` (0–100), `completedTasks`,
  `totalTasks`, `capturedAt`.
- **Когда снимать:** не на каждое изменение (шумно), а «не чаще раза в день на цель». Точка
  захвата — при загрузке модуля (`PlanningNotifier.build`/`_load`): для каждой активной цели, если
  сегодня снимка ещё нет — записать текущий `goalProgress(goal)`. Дёшево и достаточно для трендов.
- Локально (Drift) — основной источник; зеркалирование в Supabase для кросс-девайс истории
  (синк-очередь, как у остального).

### Вычисления (чистые функции в новом `analytics` или `planning.dart`)
- `velocityPerWeek(snapshots)` — линейная регрессия/простая дельта за окно 7–14 дней.
- `projectedCompletion(goal, velocity)` — `now + (100 - progress) / velocityPerDay`. Если
  velocity ≤ 0 → «темп нулевой» (без прогноза).
- `burndownSeries(goal)` — идеальная линия от `createdAt`/`progress` к `deadline`/100%.
- `momentumState(goal)` → enum `{ accelerating, steady, stalling, atRisk }` для бейджа.

### UI
- Секция «Импульс» в `GoalStatsScreen` (расширяем существующий экран — он уже карточный).
- Графики: лёгкий `CustomPainter` (консистентно с эстетикой SiE и без тяжёлых зависимостей) —
  переиспользовать спарклайн из этапа 4, расширив до полноценного line+target chart. Если решим
  ввести `fl_chart` — см. открытые вопросы.

### Edge cases
- **Мало данных** (< 3 снимков) — не показывать прогноз, писать «Собираем данные о темпе…».
- **Не монотонный прогресс** (откат при добавлении новых задач — знаменатель вырос) — это нормально;
  показывать честно, прогноз сглаживать окном.
- **Нет дедлайна** — burndown скрыт, прогноз/velocity остаются.
- **Цель завершена/заморожена** — фиксируем финальный снимок, аналитика становится «ретроспективой».
- Хранение: снимки маленькие, но для очень старых целей можно прореживать (>90 дней — раз в неделю).

## Затрагиваемые модули

| Файл | Действие |
|---|---|
| `packages/sie_core/lib/src/local/app_database.dart` | +таблица `LocalGoalProgressSnapshots`; метод `snapshotIfNeeded`; `schemaVersion → 20`; миграция |
| `packages/sie_core/lib/src/models/goal_analytics.dart` | **NEW** — `MomentumStats`, чистые функции velocity/projection/burndown/momentumState |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | в `_load` — захват ежедневного снимка для активных целей |
| `packages/sie_core/lib/src/providers/goal_analytics_provider.dart` | **NEW** — `family`-провайдер аналитики по `goalId` |
| `supabase/migrations/<ts>_goal_progress_snapshots.sql` | **NEW** — таблица + RLS + индекс `(goal_id, captured_at)` |
| `apps/central_hub/lib/screens/goal_stats_screen.dart` | +секция «Импульс» (график, темп, прогноз, burndown) |
| `apps/central_hub/lib/screens/planning_screen.dart` | мини-индикатор импульса на карточке цели |
| `apps/central_hub/lib/widgets/momentum_chart.dart` | **NEW** — `CustomPainter` line/target/burndown |

## Схема данных

```sql
CREATE TABLE public.goal_progress_snapshots (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id         uuid NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  progress        real NOT NULL,
  completed_tasks int  NOT NULL DEFAULT 0,
  total_tasks     int  NOT NULL DEFAULT 0,
  captured_at     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_snapshot_goal_day
  ON public.goal_progress_snapshots(goal_id, (captured_at::date));  -- 1 снимок/день/цель
-- RLS: owner + accepted collaborators (через goals), read; insert — owner/editor
```

## Открытые вопросы

1. **Библиотека графиков.** `fl_chart` (быстро, красиво, +зависимость) против собственного
   `CustomPainter` (полный контроль над эстетикой SiE, ноль зависимостей). Рекомендация: **свой
   `CustomPainter`** — у проекта уже есть культура кастомных пейнтеров (тактическая карта,
   орбы); это сохранит фирменный вид и не раздует бандл.
2. **Где считать velocity** — клиент или серверный RPC? Рекомендация: **клиент** (данных мало,
   офлайн-доступность важнее).
3. **Частота снимков** — раз в день достаточно? Рекомендация: да; для «живости» можно
   до-захватывать снимок при крупном событии (завершение под-цели), но не чаще 1/день в основном
   ряду.
