# Plan: Исправления совместной работы в модуле Планирования

## Контекст

Три недоработки в режиме совместной работы над целями, обнаруженные после релиза v2.5.21:
1. Пользователи с ролью «только чтение» могут вносить изменения через незащищённые виджеты
2. Кнопки в заголовке MissionDetailScreen переполняют строку и ViewToggle уходит за экран
3. После отправки приглашения кнопка «Позвать» остаётся активной, при повторном нажатии — скрытая ошибка

---

## Фикс 1: Пропуск canEdit в дочерних виджетах

**Файлы:** `apps/central_hub/lib/screens/mission_detail_screen.dart`, `tactical_map_view.dart`

### Что нарушено (конкретные места):

| Виджет / строки | Проблема |
|---|---|
| `_TaskTile` чекбокс ~1039 | toggleTask вызывается без проверки `canEdit` |
| `_TaskTile` кнопка удаления ~1075 | _confirmDeleteTask без проверки |
| `_TaskTile` drag handle ~1034 | ReorderableDragStartListener всегда активен |
| `ReorderableListView.onReorder` ~861 | reorderTasks вызывается без проверки |
| `_AddTaskRow` ~1140 | виджет не принимает `canEdit`, всегда видим |
| `_AddChildSubGoalRow` ~1114 | аналогично |
| `TacticalMapView` ~134 | не получает `canEdit`, контекстное меню всегда полное |

### Исправления:

**A. `_TaskTile`** — добавить `canEdit` параметр:
```dart
// Чекбокс: onTap только если canEdit
onTap: canEdit ? () => ref.read(planningProvider.notifier).toggleTask(...) : null,

// Кнопка удаления: скрыть if (!canEdit)
if (canEdit) GestureDetector(onTap: _confirmDeleteTask, child: Icon(Icons.close)),

// Drag handle: скрыть if (!canEdit)
if (canEdit) ReorderableDragStartListener(...)
```

**B. `ReorderableListView.onReorder`** в `_SubGoalTile` (~861):
```dart
onReorder: canEdit ? (oldIdx, newIdx) { ... reorderTasks(...) } : (_, __) {},
```

**C. `_AddTaskRow` и `_AddChildSubGoalRow`** — добавить параметр `canEdit`, возвращать `const SizedBox.shrink()` если `!canEdit`

**D. Все вызывающие стороны** — передавать `canEdit: canEdit` в `_TaskTile`, `_AddTaskRow`, `_AddChildSubGoalRow`

**E. `TacticalMapView`** — добавить параметр `final bool canEdit` в конструктор.
Передача: `TacticalMapView(goal: goal, canEdit: canEdit)` (строка ~134).
Внутри `TacticalMapView` — в каждом context-sheet скрывать кнопки редактирования:
- `_showSubGoalSheet`: кнопки «Добавить задачу», «Добавить под-цель», «Удалить», «Завершить» — только если `canEdit`
- `_showTaskSheet`: toggle/delete — только если `canEdit`
- `_showGoalSheet`: кнопки добавления — только если `canEdit`
- `_showMilestoneSheet`: complete/delete — только если `canEdit`
- Drag & drop узлов: `onPanUpdate/onPanEnd` — только если `canEdit`

---

## Фикс 2: Переполнение заголовка MissionDetailScreen

**Файл:** `apps/central_hub/lib/screens/mission_detail_screen.dart`, класс `_MissionHeader`

### Текущая правая часть заголовка:
```
[AI ✨] [⚙️] [📊] [Список|Карта]
~28px   ~28px  ~28px   ~64px  = ~172px + SizedBox(8) × 3 = ~196px
```

На узких экранах (360px) после Spacer не хватает места.

### Решение — переместить AI-кнопку влево (до Spacer):
```dart
Row(children: [
  IconButton(back),
  if (fatigued) Icon(warning),
  _StatusChip,
  if (isShared) Icon(people),
  if (onAiDecompose != null) ...[          // ← AI-кнопка ЗДЕСЬ
    const SizedBox(width: 4),
    IconButton(auto_awesome, onAiDecompose),
  ],
  const Spacer(),
  if (onSettings != null) IconButton(settings),  // ← без SizedBox перед ним
  IconButton(bar_chart),
  const SizedBox(width: 4),
  _ViewToggle,
])
```

Правая сторона сокращается до `[⚙️] [📊] [Список|Карта]` ≈ 120px — умещается на любом экране.

AI-кнопка слева от Spacer органично смотрится рядом с индикаторами статуса.

Также убрать все `const SizedBox(width: 8)` между правыми кнопками, заменить на `const SizedBox(width: 4)`.

---

## Фикс 3: Состояние кнопки приглашения в CollaboratorPickerSheet

**Файл:** `apps/central_hub/lib/screens/mission_detail_screen.dart`, класс `_CollaboratorPickerSheet`

### Корень проблемы:
Picker использует `widget.goal` (снимок в момент открытия). После отправки приглашения `planningProvider` инвалидируется и перезагружается, но picker видит старые данные — pending-пользователь не попадает в `existingIds` и снова показывается с активной кнопкой.

### Решение:

**1. Читать живые данные из `planningProvider`:**
```dart
final liveGoal = ref.watch(planningProvider).valueOrNull
    ?.goals.firstWhere((g) => g.id == widget.goal.id,
        orElse: () => widget.goal) ?? widget.goal;
```

**2. Изменить фильтр** — скрывать только `accepted` (не `pending`/`declined`):
```dart
final acceptedIds = liveGoal.collaborators
    .where((c) => c.status == 'accepted')
    .map((c) => c.userId)
    .toSet();

final pendingIds = liveGoal.collaborators
    .where((c) => c.status == 'pending')
    .map((c) => c.userId)
    .toSet();

final available = friends
    .where((f) => !acceptedIds.contains(f.otherUser.id))
    .toList();
```

**3. Состояние кнопки для каждого пользователя:**
```dart
final isPending = pendingIds.contains(friend.otherUser.id);

// Кнопка:
OutlinedButton(
  onPressed: isPending || _invitingUserId != null ? null : () => _invite(context, ...),
  child: _invitingUserId == friend.id
    ? SizedBox(16, 16, CircularProgressIndicator)
    : Text(isPending ? 'ОТПРАВЛЕНО' : 'ПОЗВАТЬ'),
)
```

Дополнительно: при `declined` статусе пользователь снова попадает в список с активной кнопкой «Позвать» — это корректное поведение.

---

## Критические файлы

| Файл | Изменения |
|---|---|
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | Фикс 1 (TaskTile, AddTaskRow, AddChildSubGoalRow), Фикс 2 (MissionHeader), Фикс 3 (CollaboratorPickerSheet) |
| `apps/central_hub/lib/screens/tactical_map_view.dart` | Фикс 1 (добавить canEdit параметр + защита всех context-sheets и drag) |

---

## Проверка

1. `flutter analyze` — 0 ошибок
2. **Фикс 1 (readonly):** Войти в цель как коллаборатор-viewer → убедиться что чекбоксы задач не нажимаются, кнопки добавления отсутствуют, drag handle пропал, в тактической карте контекстное меню только для просмотра
3. **Фикс 2 (header):** Открыть цель где есть AI-кнопка + settings → ViewToggle полностью видим на экране
4. **Фикс 3 (invite):** Пригласить пользователя → закрыть picker → снова открыть → кнопка показывает «ОТПРАВЛЕНО» и заблокирована; после отклонения — снова «ПОЗВАТЬ»
