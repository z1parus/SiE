# Этап 4 — Количественные вехи (метрики)

## Описание

Сейчас `Milestone` — бинарная отметка («достигнуто/нет»). Но огромный класс реальных целей
**измерим числом во времени**: вес (80 кг), накопления ($5000), дистанция (бег 42 км), словарный
запас (2000 слов), вес штанги, подписчики. Концепт-документ модуля прямо упоминает пример «80 кг
на весах», но реализация осталась бинарной. Этот этап превращает веху в **трекер метрики**: у неё
есть стартовое, текущее и целевое значение, единица измерения и **журнал замеров** — пользователь
периодически вносит показания, видит график динамики и автоматический процент достижения.

Это даёт модулю «измеримость» — то, без чего цель «похудеть» или «накопить» остаётся аморфной.

## Пользовательский сценарий

1. При создании вехи пользователь выбирает тип: **Бинарная** (как сейчас) или **Метрика**.
2. Для метрики задаёт: название («Вес»), стартовое значение (90), целевое (80), единицу («кг»),
   направление (уменьшать/увеличивать).
3. На экране цели веха-метрика показывает: текущее значение, **мини-спарклайн** динамики, процент
   до цели («осталось 4 кг — 60% пути»).
4. Кнопка **«Внести замер»** → диалог с одним числовым полем → новое показание добавляется в журнал
   с датой. График и процент обновляются.
5. При достижении цели (текущее пересекло целевое в нужном направлении) — веха авто-отмечается
   выполненной, +500 XP (как сейчас за milestone), празднование.
6. История замеров доступна как список + график (можно открыть на весь экран).

## Логика и поведение

### Расширение модели
- `Milestone` получает поля:
  - `kind: String` — `'binary'` (дефолт) | `'metric'`.
  - `unit: String?` — единица («кг», «$», «км»).
  - `startValue: double?`, `targetValue: double?`, `currentValue: double?`.
  - `direction: String?` — `'down'` | `'up'` (для расчёта прогресса и условия достижения).
- Новая сущность `MilestoneLog` (журнал замеров): `id`, `milestoneId`, `value`, `recordedAt`.

### Расчёт прогресса метрики
```
progress = ((current - start) / (target - start)).clamp(0, 1)   // знак учитывается направлением
```
- Для `direction='down'` (вес): прогресс растёт по мере уменьшения current.
- Достижение: `direction='up' ? current >= target : current <= target`.
- При достижении — `completeMilestone(...)` (существующий метод, +500 XP), но не «откатывать»
  при последующих колебаниях (once completed — stays, чтобы не мигало).

### Внесение замера
- Новый метод `addMilestoneLog(milestoneId, goalId, value)` в `PlanningNotifier`:
  - optimistic: добавить в журнал, обновить `currentValue` вехи (последнее показание);
  - upsert в Drift + sync;
  - проверить условие достижения → при достижении вызвать `completeMilestone`.
- `currentValue` = значение последнего по дате замера (а не max/min) — честная «текущая» картина.

### Визуализация
- Спарклайн — лёгкий `CustomPainter` (без тяжёлых библиотек) по точкам журнала.
- Полноэкранный график — переиспользовать подход аналитики (этап 5) или `fl_chart`, если решим
  его вводить (см. этап 5, открытые вопросы по библиотеке графиков).

### Edge cases
- **Один замер** — спарклайн как точка, прогресс по start→current.
- **Замер «мимо» направления** (вес вырос при цели худеть) — прогресс падает, это нормально и
  мотивирует; веха НЕ откатывается из completed, если уже была достигнута.
- **start == target** — деление на ноль → прогресс 100% при достижении значения; защититься.
- **Удаление замера** — пересчитать currentValue по предыдущему; разрешить из истории.
- Бинарные вехи работают как раньше (полная обратная совместимость; `kind='binary'`).

## Затрагиваемые модули

| Файл | Действие |
|---|---|
| `packages/sie_core/lib/src/local/app_database.dart` | +колонки в `LocalMilestones` (`kind`,`unit`,`startValue`,`targetValue`,`currentValue`,`direction`); +таблица `LocalMilestoneLogs`; `schemaVersion → 19`; миграция |
| `packages/sie_core/lib/src/models/planning.dart` | расширить `Milestone`; +модель `MilestoneLog`; +функция `metricProgress(milestone)` |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | +`addMilestoneLog`, `deleteMilestoneLog`, `updateMilestoneMetric`; учёт метрик-веха в `addMilestone` |
| `supabase/migrations/<ts>_milestone_metrics.sql` | **NEW** — ALTER `milestones` + `CREATE TABLE milestone_logs` + RLS |
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | UI вехи-метрики: текущее значение, спарклайн, кнопка «Внести замер» |
| `apps/central_hub/lib/screens/milestone_metric_screen.dart` | **NEW** (опц.) — полноэкранный график + история замеров |
| `apps/central_hub/lib/widgets/sparkline.dart` | **NEW** — лёгкий `CustomPainter` спарклайн |

## Схема данных

```sql
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS kind          text NOT NULL DEFAULT 'binary',  -- 'binary'|'metric'
  ADD COLUMN IF NOT EXISTS unit          text,
  ADD COLUMN IF NOT EXISTS start_value   double precision,
  ADD COLUMN IF NOT EXISTS target_value  double precision,
  ADD COLUMN IF NOT EXISTS current_value double precision,
  ADD COLUMN IF NOT EXISTS direction     text DEFAULT 'up';                -- 'up'|'down'

CREATE TABLE public.milestone_logs (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id uuid NOT NULL REFERENCES public.milestones(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES public.profiles(id)   ON DELETE CASCADE,
  value        double precision NOT NULL,
  recorded_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_milestone_logs_ms ON public.milestone_logs(milestone_id, recorded_at DESC);
-- RLS: owner/editor цели (через join milestones→goals), как у planning_tasks
```

## Открытые вопросы

1. **Хранить ли весь журнал в Supabase или агрегировать?** Рекомендация: хранить замеры (их немного
   на веху) — нужны для графика и честной истории; индекс по `(milestone_id, recorded_at)`.
2. **Связь с привычками-количественными** (если в трекере привычек есть числовые привычки) — стоит
   ли позволить «питать» веху-метрику из привычки? Перспективно, но усложняет; вынести в будущее.
3. **Виджеты ввода** — числовая клавиатура + быстрые ±шаги? Рекомендация: поле + стандартная
   числовая клавиатура; быстрые шаги (±0.1/±1) для удобства веса.
