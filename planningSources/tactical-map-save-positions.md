# Тактическая карта: сохранение положения элементов

## Описание

Сейчас все позиции элементов на тактической карте — эфемерное UI-состояние (`Map<String, Offset> _positions` в `StatefulWidget`). При каждом открытии карты позиции пересчитываются алгоритмически заново (круговое расположение). Пользователь не может «разложить карту под себя» — его расстановка пропадает при уходе с экрана.

Задача: сохранять позиции всех элементов карты после каждого перетаскивания и восстанавливать их при следующем открытии.

---

## Пользовательский сценарий

Пользователь открывает тактическую карту миссии. Элементы расположены по умолчанию (алгоритмически). Он начинает «обустраивать» карту: тянет подцели, задачи, контрольные точки — раскладывает так, как удобно читать именно ему. После каждого перемещения расположение автоматически сохраняется (без кнопок, без явного подтверждения).

Пользователь уходит с экрана, возвращается — карта выглядит точно так же, как он её оставил. Это работает между сессиями приложения и после перезапуска.

Если пользователь добавляет новый элемент (задачу, подцель и т.д.) — он появляется на карте в позиции по умолчанию (алгоритмической), рядом с родителем. После того как пользователь перетащил его — позиция запоминается.

---

## Архитектурное решение: JSON-колонка на `goals`

### Варианты

**Вариант A: `pos_x` / `pos_y` на каждой сущности**
- Изменения в 5 таблицах (sub_goals, planning_tasks, milestones, goal_habit_links, goals)
- 5 моделей, 5 Drift-таблиц, 5 миграций
- Позиции обновляются поштучно при каждом drag

**Вариант B: отдельная таблица `map_positions(entity_id, entity_type, goal_id, pos_x, pos_y)`**
- Одна новая таблица, нет изменений в существующих
- Требует JOIN или отдельный запрос при загрузке карты

**Вариант C: JSON-колонка `map_positions` на таблице `goals` ← выбранный**
- Одна колонка на одной таблице
- Позиции всех элементов карты хранятся вместе: `{"<element_id>": {"x": 123.0, "y": -45.0}, ...}`
- При открытии карты данные уже доступны — Goal грузится целиком
- При сохранении — один UPDATE на таблицу goals
- Минимальный охват изменений

### Почему C

Позиции — это **свойство карты**, а не свойство задачи или подцели. Задача одна и та же в любом контексте, но её место на карте принадлежит конкретной карте (Goal). JSON на Goal идеально соответствует этой семантике. Аналогично тому, как в таблице goals уже есть `settings` JSON.

---

## Логика и поведение

### Структура данных

Новое поле `mapPositions` в модели `Goal`:

```dart
// В Goal
final Map<String, Offset>? mapPositions;
// Null = позиции не сохранены (будет использован алгоритм)
```

Формат хранения (JSON):
```json
{
  "sub_goal_id_abc": {"x": 240.0, "y": 0.0},
  "task_id_xyz": {"x": 385.0, "y": 145.0},
  "milestone_id_001": {"x": -200.0, "y": 150.0},
  "habit_link_id_qwe": {"x": 320.0, "y": -90.0}
}
```

Координаты — canvas-relative (относительно центра, `Offset.zero` = позиция Goal). Это тот же формат, что сейчас в `Map<String, Offset> _positions`.

### Загрузка позиций (`_ensurePositions`)

Текущая логика: если позиция для элемента не в `_positions` — вычислить алгоритмически.

Новая логика:
```
для каждого элемента карты:
  если goal.mapPositions содержит его id:
    взять сохранённую позицию
  иначе:
    вычислить алгоритмически (как сейчас)
    добавить в pendingSave (будет сохранено вместе с первым drag)
```

Таким образом новые элементы появляются в алгоритмической позиции и запоминаются при первом же взаимодействии с картой.

### Сохранение позиций (после drag)

Сохранение происходит в `onPanEnd` — после отпускания элемента.

**Дебаунс 300ms**: если пользователь перетаскивает несколько элементов подряд (tap-tap-tap), все изменения батчатся в одно сохранение, а не по одному UPDATE на каждый.

```dart
Timer? _saveTimer;

void _scheduleSave(Goal goal) {
  _saveTimer?.cancel();
  _saveTimer = Timer(const Duration(milliseconds: 300), () {
    ref.read(planningProvider.notifier).saveMapPositions(goal.id, Map.of(_positions));
  });
}
```

`_saveTimer` инициализируется в State, отменяется в `dispose`.

### Метод провайдера `saveMapPositions`

```dart
Future<void> saveMapPositions(String goalId, Map<String, Offset> positions) async {
  // Сериализация
  final json = positions.map((id, offset) => MapEntry(id, {'x': offset.dx, 'y': offset.dy}));
  
  // Обновление локального Drift
  await db.updateGoalMapPositions(goalId, jsonEncode(json));
  
  // Обновление Supabase
  await supabase.from('goals').update({'map_positions': json}).eq('id', goalId);
  
  // Обновление state (чтобы goal.mapPositions отражал актуальные данные)
  state = state.whenData((s) => s.copyWithGoalPositions(goalId, positions));
}
```

### Инвалидация позиций при удалении элемента

Когда элемент удаляется с карты — его ключ из `mapPositions` нужно убрать, иначе копится мусор. Это делается в существующих методах `deleteTask`, `deleteSubGoal`, `deleteMilestone` провайдера: после удаления вызывается `saveMapPositions` с уже обновлённым `_positions` (без удалённого id).

В UI: при `onPanEnd` после reparent позиция сохраняется уже с новыми координатами — дополнительного кода не нужно.

---

## Схема данных

### Supabase (новая миграция)

```sql
-- Добавить колонку в goals
ALTER TABLE public.goals
  ADD COLUMN map_positions JSONB DEFAULT NULL;

COMMENT ON COLUMN public.goals.map_positions IS
  'Canvas positions of all map elements: {"<element_id>": {"x": float, "y": float}}';
```

Один ALTER TABLE, одна колонка, один файл миграции.

### Drift (локальная БД)

В `LocalGoals` (app_database.dart) добавить одно поле:
```dart
TextColumn get mapPositions => text().nullable()();
// Хранится как JSON-строка, парсится в Map<String, Offset> в модели
```

Версия схемы: **10** (сейчас 9). Миграция:
```dart
if (from == 9) {
  await m.addColumn(localGoals, localGoals.mapPositions);
}
```

### Модель Goal

```dart
class Goal {
  // ... существующие поля ...
  final Map<String, Offset>? mapPositions; // новое

  // fromJson: парсить map_positions из JSON если не null
  // toInsertJson: сериализовать mapPositions в JSON
  // copyWith: добавить mapPositions параметр
}
```

---

## Затрагиваемые модули

| Файл | Изменения |
|---|---|
| `supabase/migrations/YYYYMMDD_planning_positions.sql` | Новый файл: ALTER TABLE goals ADD COLUMN map_positions |
| `packages/sie_core/lib/src/local/app_database.dart` | `LocalGoals`: добавить `mapPositions`, версия схемы → 10, миграция v9→v10 |
| `packages/sie_core/lib/src/models/planning.dart` | `Goal`: добавить `mapPositions`, обновить `fromJson`, `copyWith`, `toInsertJson` |
| `packages/sie_core/lib/src/providers/planning_provider.dart` | Добавить метод `saveMapPositions()`, обновить `deleteTask`/`deleteSubGoal`/`deleteMilestone` |
| `apps/central_hub/lib/screens/tactical_map_view.dart` | `_ensurePositions` — использовать сохранённые позиции, добавить `_scheduleSave` + `_saveTimer` |

Итого: 5 файлов + 1 новый SQL. Все изменения строго локализованы, никакие другие модули не затрагиваются.

---

## Открытые вопросы

Вопросов нет — архитектура однозначна.
