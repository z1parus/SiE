# Этап 5 — Распределение по участникам и цветовая кодировка

## Описание

Превращает совместную цель из «общего дерева, которое все правят» в **распределённую командную
работу**: задачи и под-цели можно **назначать конкретным участникам** (owner + принятые
коллабораторы), а на тактической карте **визуально различать, чьё что** — по цвету и аватару.

Сейчас коллаборация — только уровня цели (`goal_collaborators`, роли viewer/editor); **поузлового
назначения нет** (подтверждено аудитом: ни `PlanningTask`, ни `SubGoal` не имеют `assignedTo`).
Этот этап закрывает пробел и делает карту «доской ответственности».

## Пользовательский сценарий

1. В sheet задачи/под-цели (карта и список) — секция **«Исполнитель»**: список участников цели
   (owner + accepted-коллабораторы из `goal.collaborators`) с аватарами; можно назначить одного
   (MVP) или нескольких.
2. Каждому участнику автоматически присваивается **цвет** из палитры (детерминированно по `userId`).
   Над/у узла на карте — **мини-аватар назначенного** + тонкая **цветовая окантовка/тинт** узла в
   цвет участника.
3. **Легенда участников** (оверлей карты): список участников с их цветами; тап по участнику →
   **фильтр** «показать только его задачи» (остальные приглушаются, как Fog of War).
4. Быстрый режим **«Мои задачи»** — подсветить узлы, назначенные на меня.
5. Назначение порождает (опц.) уведомление участнику «Вам назначена задача …» (переиспользует
   существующую систему нотификаций).

## Логика и поведение

### Модель назначения
- Таблицы связей: `planning_task_assignees` (task↔user) и `sub_goal_assignees` (subgoal↔user),
  обе с денормализованным `goal_id` для RLS (паттерн `task_dependencies` из
  `20260615000006`).
- MVP — один исполнитель на узел (UI), но таблица many-to-many (на вырост — несколько).
- Назначать можно только участников цели (owner ∨ accepted-коллаборатор); валидация на клиенте + RLS.

### Цвета участников
- Детерминированная палитра: `memberColor(userId)` → стабильный цвет из набора 8 акцентов
  (hash → индекс). Owner — фирменный `c.accent`. Чистая функция в `sie_core` (переиспользуется
  легендой, узлами, аватар-бейджами).

### Рендер на карте
- В `_SubGoalNode`/`_TaskNode` — опц. **цветовая окантовка** (border/тинт) в цвет исполнителя и
  **мини-аватар** (24px, `cached_network_image`) в углу.
- Легенда — оверлей (как зум-кнопки), сворачиваемая; показывается только если у цели есть
  коллабораторы.
- Фильтр по участнику переиспользует механику приглушения (`Opacity`), уже применяемую для Fog of War.

### Права
- Назначать/снимать может owner/editor (`canEdit`). Viewer видит назначения и цвета.
- Назначенный-viewer **не** получает право редактировать задачу (роль цели важнее назначения) —
  назначение здесь про ответственность/визуализацию, не про права. (Расширение прав по назначению —
  открытый вопрос.)

### Edge cases
- **Участник удалён из коллаборации** → его назначения каскадно удаляются (`ON DELETE CASCADE` по
  user/goal); узлы возвращаются к «без исполнителя».
- **Перенос задачи** (`moveTask`) — назначение сохраняется (привязка к task, не к subgoal).
- **Личная (несовместная) цель** — секция «Исполнитель» скрыта/тривиальна (только owner); цветовая
  кодировка не показывается.
- **Производительность** — назначения грузятся одним запросом и кладутся в `Map<nodeId, userId>` на
  `Goal`; аватары — лениво.

## Затрагиваемые модули

| Файл | Действие |
|---|---|
| `packages/sie_core/lib/src/local/app_database.dart` | +таблицы `LocalTaskAssignees`, `LocalSubGoalAssignees`; `schemaVersion → 34`; миграция |
| `packages/sie_core/lib/src/models/planning.dart` | `PlanningTask`/`SubGoal` +`List<String> assigneeIds`; `Goal` геттер `assigneesFor(nodeId)`; функция `memberColor(userId)` |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | загрузка назначений; `assignNode(nodeType,nodeId,userId)`/`unassignNode`; уведомление участнику |
| `packages/sie_core/lib/src/services/sync_service.dart` | +`case 'assign_node'`, `case 'unassign_node'` |
| `supabase/migrations/<ts>_node_assignees.sql` | **NEW** — 2 таблицы + RLS + индексы |
| `apps/central_hub/lib/screens/tactical_map_view.dart` | окантовка/тинт + мини-аватар на узлах; легенда участников (оверлей); фильтр по участнику; режим «Мои задачи» |
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | секция «Исполнитель» в sheets/тайлах; (опц.) бейдж исполнителя в списке |

## Схема данных

### Drift
```dart
@DataClassName('LocalTaskAssignee')
class LocalTaskAssignees extends Table {
  TextColumn get taskId     => text()();
  TextColumn get userId     => text()();
  TextColumn get goalId     => text()();
  TextColumn get assignedBy => text()();
  IntColumn  get createdAtMs=> integer()();
  BoolColumn get synced     => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {taskId, userId};
}
// аналогично LocalSubGoalAssignees (subGoalId,userId). schemaVersion => 34
```

### Supabase
```sql
CREATE TABLE public.planning_task_assignees (
  task_id     uuid NOT NULL REFERENCES public.planning_tasks(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  goal_id     uuid NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,  -- денорм. для RLS
  assigned_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (task_id, user_id)
);
CREATE INDEX idx_task_assignee_goal ON public.planning_task_assignees(goal_id);
-- аналогично sub_goal_assignees (sub_goal_id, user_id, goal_id, ...)
-- RLS SELECT: владелец/принятый коллаборатор цели.
-- RLS INSERT/DELETE: владелец/editor цели; назначаемый user_id должен быть участником цели.
```

## Открытые вопросы

1. **Один или несколько исполнителей.** Рекомендация: таблица many-to-many, UI MVP — один (radio);
   мульти-назначение включить позже без миграции.
2. **Даёт ли назначение права редактирования** именно этой задачи участнику-viewer? Рекомендация:
   нет в MVP (роль цели — источник истины); «делегированное право на свою задачу» — отдельная фича.
3. **Палитра цветов и доступность.** Рекомендация: 8 различимых акцентов SiE + проверка контраста;
   owner всегда `c.accent`.
4. **War Room (этап 1 PlanningModuleEvolution)** — добавить фильтр «назначено на меня» в повестку?
   Рекомендация: да, как естественное расширение, но вне scope этого этапа карты.
