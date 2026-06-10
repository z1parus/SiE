# Режим списка — сортировка элементов и исправление счётчиков

## Описание

Две доработки списочного режима экрана цели (`mission_detail_screen.dart`):

1. **Перетаскивание элементов** — пользователь может менять порядок под-целей и задач в списке, порядок сохраняется и восстанавливается при следующем открытии.
2. **Корректные счётчики задач** — в заголовке под-цели показывать суммарное количество задач всего поддерева, а не только прямых задач.

---

## Фича 1 — Перетаскивание элементов списка

### Пользовательский сценарий

- Пользователь зажимает под-цель (или задачу) в списке — появляется иконка drag handle
- Тянет вверх или вниз — элемент перемещается среди **сиблингов того же уровня**
- Отпускает — новый порядок мгновенно сохраняется локально и синхронизируется с Supabase

### Текущее состояние

**Под-цели (SubGoal):**
- `orderIndex: int` уже есть в модели, в таблице `local_sub_goals` и в Supabase (`order_index`)
- При загрузке уже сортируются по `orderIndex`
- Метода `reorderSubGoals` в провайдере пока нет

**Задачи (PlanningTask):**
- `orderIndex` **отсутствует** — ни в модели, ни в БД, ни в Supabase
- Сейчас сортируются по `createdAtMs`
- Нужна миграция

### Логика и поведение

- Drag-and-drop работает только **в пределах одного уровня** (root или конкретный parent). Перетаскивание под-цели не меняет её `parentSubGoalId`.
- При сбросе позиции провайдер получает новый порядок ID `List<String>` и переприсваивает `orderIndex` = 0, 1, 2, ... по порядку.
- Drag handle (`Icons.drag_handle`) отображается справа от каждой под-цели и задачи.
- `ReorderableListView.builder` для корневых под-целей; вложенные под-цели и задачи — обёртка в `ReorderableListView` внутри раскрытой карточки.
- Сохранение оптимистичное (state обновляется мгновенно), затем запись в Drift и в Supabase.

### Затрагиваемые модули

| Файл | Изменения |
|------|-----------|
| `packages/sie_core/lib/src/models/planning.dart` | Добавить `orderIndex: int` в `PlanningTask` (конструктор, `copyWith`, `fromJson`) |
| `packages/sie_core/lib/src/local/app_database.dart` | Добавить `orderIndex` в `LocalPlanningTasks`; bump schema до v11; миграция `addColumn`; обновить запрос загрузки задач — сортировать по `orderIndex` |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | Добавить методы `reorderSubGoals(String goalId, String? parentId, List<String> newOrder)` и `reorderTasks(String subGoalId, List<String> newOrder)` |
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | `_SubGoalsSection`: заменить `Column` с `...goal.subGoals.map(...)` на `ReorderableListView`; добавить drag handles; аналогично для задач внутри `_SubGoalTile` |
| `supabase/migrations/` | Новый файл: `ALTER TABLE planning_tasks ADD COLUMN order_index INTEGER DEFAULT 0` |

### Схема данных

**Новый столбец:**
```sql
ALTER TABLE public.planning_tasks ADD COLUMN IF NOT EXISTS order_index INTEGER DEFAULT 0;
```

**Drift (schema v11):**
```dart
// В LocalPlanningTasks:
IntColumn get orderIndex => integer().withDefault(const Constant(0))();

// Миграция:
if (from < 11) {
  await m.addColumn(localPlanningTasks, localPlanningTasks.orderIndex);
}
```

**Загрузка задач — изменить orderBy:**
```dart
// было:
..orderBy([(t) => OrderingTerm(expression: t.createdAtMs)])
// стало:
..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])
```

**Новые методы провайдера:**

```dart
Future<void> reorderSubGoals(
  String goalId,
  String? parentId,      // null = корневые под-цели
  List<String> newOrder, // новый порядок ID
) async {
  // 1. Оптимистично обновить state
  // 2. Записать новые orderIndex в Drift (UPDATE)
  // 3. Синхронизировать с Supabase
}

Future<void> reorderTasks(
  String subGoalId,
  List<String> newOrder,
) async {
  // Аналогично для задач
}
```

### UI — `_SubGoalsSection`

**Было:** `Column` с `...goal.subGoals.map((sg) => _SubGoalTile(...))`

**Стало:** `ReorderableListView` (shrinkWrap: true, physics: NeverScrollableScrollPhysics):
```dart
ReorderableListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: goal.subGoals.length,
  buildDefaultDragHandles: false,
  onReorder: (oldIndex, newIndex) {
    final ids = goal.subGoals.map((sg) => sg.id).toList();
    // стандартная onReorder корректировка индекса
    ref.read(planningProvider.notifier).reorderSubGoals(goal.id, null, ids);
  },
  itemBuilder: (ctx, i) {
    final sg = goal.subGoals[i];
    return ReorderableDragStartListener(
      key: ValueKey(sg.id),
      index: i,
      child: _SubGoalTile(sg: sg, ...),
    );
  },
)
```

Drag handle иконка — добавить `ReorderableDragStartListener` или `ReorderableDelayedDragStartListener` к существующей плитке, показывать `Icons.drag_handle` с правой стороны плитки.

### Задачи внутри `_SubGoalTile`

Аналогично — `ReorderableListView.builder` для `sg.tasks` с `onReorder` вызывающим `reorderTasks(sg.id, newOrder)`.

---

## Фича 2 — Корректные счётчики задач

### Пользовательский сценарий

Под-цель «Проект X» содержит:
- 2 прямые задачи
- Дочернюю под-цель «Этап 1» с 3 задачами

Текущий вид заголовка: `1/2 задач · 40%`
Нужный вид: `1/5 задач · 40%` (суммарно по всему поддереву)

Дополнительно: если под-цель содержит вложенные дочерние под-цели, показывать их количество:
`1/5 задач · 2 этапа · 40%`

### Логика и поведение

Добавить в `mission_detail_screen.dart` (или в `planning.dart`) вспомогательные функции:

```dart
/// Суммарное количество задач в поддереве (включая вложенные)
int _totalTasks(SubGoal sg) {
  int n = sg.tasks.length;
  for (final c in sg.children) n += _totalTasks(c);
  return n;
}

/// Суммарное количество выполненных задач в поддереве
int _completedTasks(SubGoal sg) {
  int n = sg.tasks.where((t) => t.isCompleted).length;
  for (final c in sg.children) n += _completedTasks(c);
  return n;
}

/// Суммарное количество дочерних под-целей (всех уровней)
int _totalSubGoals(SubGoal sg) {
  int n = sg.children.length;
  for (final c in sg.children) n += _totalSubGoals(c);
  return n;
}
```

**Строка подписи под-цели (строка 669 сейчас):**
```dart
// было:
'$done/$total задач · ${prog.round()}%'

// стало:
() {
  final totalT = _totalTasks(sg);
  final doneT = _completedTasks(sg);
  final subCount = sg.children.length; // прямые дочерние под-цели
  final subPart = subCount > 0 ? ' · $subCount эт.' : '';
  return '$doneT/$totalT задач$subPart · ${prog.round()}%';
}()
```

### Затрагиваемые модули

| Файл | Изменения |
|------|-----------|
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | Добавить 3 helper-функции + обновить строку подписи в `_SubGoalTile.build` |

Модели и провайдер не меняются — `subGoalProgress` уже считает прогресс рекурсивно, нужно только починить строку отображения счётчика.

---

## Открытые вопросы

1. **Drag handle по зажатию или сразу?** — `ReorderableDelayedDragStartListener` (долгое нажатие активирует drag) или `ReorderableDragStartListener` (drag с первого движения)? Рекомендуется `ReorderableDelayedDragStartListener` чтобы не конфликтовать с tap/longPress на плитке.

2. **Миграция Supabase** — как обычно, файл создаётся, но применяется вручную через Dashboard (supabase db push недоступен без пароля).

3. **Формат «этапов» в подписи** — показывать только прямые дочерние (`sg.children.length`) или все уровни (`_totalSubGoals(sg)`)? Рекомендуется показывать только прямые — менее запутанно для пользователя.
