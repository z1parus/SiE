# Сценарное планирование / War Gaming — ветвление и симуляция карты

> Папка: `TacticalMapThreesearch`. Идея 3 из 3 (SIMULATION).
> Связана с: `PlanningModuleEvolution` этапы 5 (аналитика темпа — velocity/projection, реализован),
> 8 (зависимости, реализован); идея 2 (тактический ИИ-анализ — `criticalPath`/`riskScore`); этап 6
> (`createGoalFromTemplate`/`_instantiateTemplateSubGoal`, реализован — но копирует структуру без
> раскладки, см. отличие ниже).

## Описание

Карта отвечает на «как цель устроена **сейчас**». Она не отвечает на «что если»: что если
заморозить эту ветку, что если закрыть критический путь первым, что если перераспределить
исполнителей, что если сдвинуть дедлайн на месяц. Сегодня любое такое «что если» можно проверить
только разрушив реальную цель (и потом отменяя по одной).

War Gaming вводит **ветвление**: пользователь создаёт именованные **сценарии** — автономные копии
состояния цели (дерево + зависимости + карта-элементы + раскладка), в которых можно безопасно
симулировать изменения, смотреть спрогнозированный исход каждого сценария, сравнивать их
бок-о-бок и **«принять» победителя** — применить его дельту к живой цели. Карта становится
полигоном для стратегических игр.

**Главный принцип:** сценарий — это **замороженный снимок + набор симулированных правок**,
живущий офлайн-first как отдельная сущность. Живая цель не трогается, пока пользователь не
коммитит. Это **симуляция** — дополнение к read-only анализу из идеи 2 (та объясняет текущую
карту, эта исследует альтернативы).

**Отличие от этапа 6 «Шаблоны миссий»** (`createGoalFromTemplate`): шаблон копирует **дерево
структуры** в **новую** цель; сценарий ветвит **ту же** цель и несёт с собой **раскладку +
карта-нативные элементы** (`mapPositions` + `mapElements`), а его дельту можно применить
обратно к живой цели. Разный объект и поток — поэтому отдельная сущность, а не «ещё один
шаблон».

## Пользовательский сценарий

1. Владелец цели на карте открывает меню «Сценарии» → «Создать сценарий» → вводит имя
   («Закрыть путь X первым»). Создаётся ветвление: копия текущего дерева + карты + раскладки.
2. В сценарии пользователь: помечает 3 задачи выполненными, замораживает под-цель «R&D»,
   переподвешивает одну ветку. **Живая цель не меняется.**
3. В нижней панели «Сценарии» видит список: `[Живая] | Сценарий A | Сценарий B`. У каждого —
   спрогнозированный исход: дата завершения, риск, длина критического пути.
   Сценарий A: «Финиш 14 июля, риск низкий».
4. Открывает **сравнение** (2 сценария бок-о-бок или Сценарий vs Живая) → две мини-карты +
   дельта-таблица (что изменилось, новый критический путь, +3 закрыто, −1 заморожено).
5. Нажимает **«Применить к живой цели»** на победителе → дельта применяется через **существующие**
   методы провайдера (`toggleTask`, `moveSubGoal`, `updateGoalSettings`, …) — XP/уведомления/синк
   срабатывают штатно. Сценарий помечается «применён».

## Логика и поведение

### Модель сценария

Строка `goal_scenarios`:

| Поле | Назначение |
|---|---|
| `id` | PK |
| `base_goal_id` | FK → `goals` (ON DELETE CASCADE) |
| `user_id` | FK → `profiles` (сценарии **личные**, см. RLS ниже) |
| `name` | название сценария |
| `snapshot_json` | полный снимок редактируемого состояния на момент ветвления |
| `edits_json` | лог симулированных правок, применяется поверх snapshot |
| `status` | `draft / applied / discarded` |
| `created_at`, `updated_at` | |
| `synced`, `deletedLocally` | offline-first, как у остальных |

`snapshot_json` — снимок редактируемого состояния: под-цели (id/name/isCompleted/order/parent/
assignees), задачи (id/subGoalId/name/weight/isCompleted/completedAt/dueDate/dependsOn/assignees/
orderIndex), вехи, habit-links, **`mapPositions`**, **`mapElements`**, `goal.settings` (включая
`deadline`). **Позиции и карта-элементы едут со снимком** — ключевая карта-нативная ценность.

`edits_json` — лог typed-правок (`{op, ref, before, after}`), применяется поверх snapshot в
in-memory «виртуальной цели» при просмотре сценария.

Виртуальная цель (`Goal`-инстанс, **не записанный в `planningProvider`**) — на ней работают
`criticalPath`/`riskScore` (идея 2) и `projectedCompletion` (этап 5) для прогноза исхода.

### Просмотр и редактирование сценария

- Переключатель «Сценарии» (как `_ViewToggle` Список/Карта) — выбор активного контекста карты:
  Живая или Сценарий N. В режиме сценария карта рендерит виртуальную цель (snapshot + edits),
  заголовок показывает «Сценарий: <name>».
- Редактирование в сценарии = применение правок к `edits_json` (не к провайдеру): complete/freeze/
  delete task, move/reparent, shift `dueDate`/`deadline`, reassign. Каждая правка — typed запись.
- `canEdit`-гейтинг: только владелец/editor создаёт/редактирует сценарии; viewer — только смотрит
  сравнение.
- Live-холст (этап 8) в режиме сценария **отключён** (нельзя collaborative-редактировать
  виртуальную цель; UX-надпись «Сценарий — локальная песочница»).

### Прогноз исхода

На виртуальной цели считаются: `projectedCompletion` (этап 5; по `velocity` живой цели — гипотеза
«темп сохранится», см. открытые вопросы), `criticalPath` (идея 2), `riskScore`-агрегат. Кэш на правку
с debounce.

### Сравнение

`ScenarioDiff(base, scenario)` → изменения по типам (completed/frozen/moved/reassigned/
deadline-shifted) + delta метрик (ΔcriticalPath, Δprojected, Δrisk). UI: две уменьшенные карты
(стиль `_MiniMap`) + таблица + бар-сравнение метрик.

### Коммит победителя

`applyScenarioToLive(goalId, scenarioId)` — прогон `edits_json` через **существующие**
notifier-методы по одной правке, в порядке «зависимости → завершения → перемещения → настройки»:
`toggleTask` / `completeSubGoal` / `moveSubGoal` / `moveTask` / `updateGoalSettings` /
`assignNode` / `unassignNode` / `removeDependency` и т.д. Это гарантирует, что XP (`_awardXp`),
автозавершение родителей (`_autoCompleteParents`), уведомления (`_syncReminders`) и синк
срабатывают штатно — мы не дублируем логику, а переиспользуем провайдер.

Перед коммитом — подтверждение с дельтой + предупреждение «это изменит живую цель». После —
`status = applied`; снимок сохраняется для истории (опц. откат — открытый вопрос).

### Edge cases

- Сценарий ссылается на task-id, удалённые в живой цели после ветвления → правка пропускается с
  пометкой «устарела».
- Цикл зависимостей в сценарии → валидация через `wouldCreateDependencyCycle` (этап 8) перед
  применением.
- Коллаборация: сценарии **личные** (per-user); другой участник не видит чужих (RLS по `user_id`).
- Лимит сценариев на цель (напр. 10) — защита от раздувания.
- Офлайн: сценарии создаются/редактируются офлайн (Drift + `PendingSyncOps`); прогноз — локальный.

## Затрагиваемые модули

| Файл | Действие |
|---|---|
| `packages/sie_core/lib/src/models/goal_scenario.dart` | **NEW** — `GoalScenario`, `ScenarioSnapshot`, `ScenarioEdit`, `ScenarioDiff`; чистые функции `applyEdits(snapshot, edits)` → виртуальная `Goal`, `computeScenarioOutcome(virtualGoal, velocity)` |
| `packages/sie_core/lib/src/local/app_database.dart` | +`LocalGoalScenarios` table; **`schemaVersion 35 → 36`**; миграция `if (from < 36) createTable`; индекс `idx_scenarios_goal` |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | +`createScenario(goalId, name)`, `applyScenarioEdit(scenarioId, edit)`, `applyScenarioToLive(goalId, scenarioId)` (прогон правок через существующие методы), `deleteScenario`; reuse `toggleTask`/`completeSubGoal`/`moveSubGoal`/`moveTask`/`updateGoalSettings`/`assignNode`/`removeDependency` |
| `packages/sie_core/lib/src/providers/goal_analytics_provider.dart` | reuse `velocityPerWeek` / `projectedCompletion` (этап 5) для прогноза сценария |
| `apps/central_hub/lib/screens/tactical_map_view.dart` | +`_scenarioContext` (живая/сценарий); рендер виртуальной цели; баннер «Сценарий: …»; панель сценариев; сравнение |
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | точка входа «Сценарии» |
| `apps/central_hub/lib/widgets/` | `_ScenarioPanel`, `_ScenarioCompareView`, `_ScenarioDiffTable` |
| `packages/sie_core/lib/src/services/sync_service.dart` | +`case` для `goal_scenarios` в синк-очереди |
| `supabase/migrations/<ts>_goal_scenarios.sql` | **NEW** — `goal_scenarios` + RLS (owner only) + индекс |

## Схема данных

```sql
CREATE TABLE public.goal_scenarios (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  base_goal_id  uuid NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name          text NOT NULL,
  snapshot_json jsonb NOT NULL,            -- полный снимок редактируемого состояния
  edits_json    jsonb NOT NULL DEFAULT '[]',
  status        text NOT NULL DEFAULT 'draft',  -- draft | applied | discarded
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_scenarios_goal ON public.goal_scenarios(base_goal_id);
-- RLS: user_id = auth.uid() (сценарии личные, даже для shared-целей)
```

Drift: `LocalGoalScenarios` (зеркало + `synced`/`deletedLocally`), `schemaVersion 36`, синк через
`PendingSyncOps` + новый `case` в `sync_service.dart`.

## Открытые вопросы

1. **Снимок vs клонирование строк.** JSON-снимок (просто, офлайн, но «виртуальная цель» не живёт в
   провайдере) vs клонирование в реальные таблицы с `scenario_id`-маркером (живее, но ломает
   RLS/запросы).
   **Рекомендация:** JSON-снимок + in-memory виртуальная цель — чище, не загрязняет основную схему.
2. **Откат коммита.** Хранить обратный diff для «отменить применение»?
   **Рекомендация:** v1 — без отката (можно создать новый сценарий «обратный»); добавить позже.
3. **Гипотеза темпа для прогноза.** Прогноз сценария берёт `velocity` из **живой** цели («темп
   сохранится»). Корректно? Альтернативы: «темп = 0» (пессимистично) или ручной ввод.
   **Рекомендация:** параметр в настройках сценария (`наследовать темп | нулевой | ручной`).
4. **Сценарии на shared-целях.** Личные per-user или общие?
   **Рекомендация:** личные (RLS по `user_id`) — избежать конфликтов правок; общий «командный
   war-gaming» — опционально позже.
5. **Live-холст в сценарии.** Отключён (нельзя collaborative-редактировать виртуальную цель).
   Подтвердить UX-надпись «Сценарий — локальная песочница».
6. **Лимит сценариев** на цель (10?) и прореживание `applied`-сценариев в истории.