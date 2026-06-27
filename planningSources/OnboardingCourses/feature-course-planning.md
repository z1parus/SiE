# План: Интерактивный курс по модулю Planning (Mission Control Tour)

> **Цель:** Обучить пользователя модулю планирования — созданию миссий, иерархии подцелей/задач/вех, Tactical Map, шаблонам и AI-декомпозиции — через интерактивный overlay-курс с подсветкой реальных элементов.

**Режим:** Планирование → Реализация
**Формат:** Интерактивный тур (coach marks) — переиспользует `CoachMarkOverlay` + `TourController` из общего плана `feature-onboarding-tour.md`.

---

## 1. Описание

Модуль Planning — самый сложный модуль SiE. Новички не понимают иерархию Миссия → Подцель → Задача → Веха, не знают про Tactical Map, Fog of War, AI-декомпозицию и шаблоны. Курс проводит по экранам `PlanningScreen` → `MissionDetailScreen` → `TacticalMapView` и объясняет каждый ключевой элемент.

### Принципы
- **Последовательный сценарий** — курс требует наличия хотя бы одной миссии; если миссий нет, первый шаг — создание демонстрационной миссии через FAB.
- **Переключение экранов** — тур navigates между Planning → MissionDetail → TacticalMap через `Navigator.push`, подсвечивая элементы на каждом.
- **Переиспользование инфраструктуры** — `TourController` расширяется новыми step-курсами; `CoachMarkOverlay` один на все курсы.
- **Киберпанк-стиль** — тот же визуальный язык: gold accent, letterSpacing 2.5, blur.
- **Пропускаемый** — кнопка «Пропустить» в любой момент. Повторный запуск из ProfileScreen → «Курсы» → «Planning».

---

## 2. Сценарий

### Точка запуска
Из `ProfileScreen` → пункт «Курс: Planning» или автоматически при первом входе в `PlanningScreen` (флаг `hasSeenCoursePlanning`).

### Предусловие
Если у пользователя 0 миссий — шаг 1 принудительно создаёт демонстрационную миссию «Операция: Демо» (через `addGoal`), чтобы остальные шаги имели что подсвечивать. По завершении курса демо-миссию можно удалить (опционально, кнопка в финальной карточке).

### Шаги курса (10 шагов)

| # | Экран | Цель (GlobalKey) | Заголовок | Суть |
|---|-------|------------------|-----------|------|
| 1 | PlanningScreen | FAB (`planning_screen.dart:93`) | Создание миссии | «Миссия — ваша главная цель. Нажмите +, чтобы создать новую. Можно с нуля, из шаблона или через AI-декомпозицию.» |
| 2 | PlanningScreen | `_ModeSwitch` (`:117`) | Повестка / Цели | «Два режима: „Повестка" — стратегический обзор дня, „Цели" — список всех миссий с прогрессом.» |
| 3 | PlanningScreen | Первый `_GoalCard` progress arc (`:749`) | Карточка миссии | «Каждая миссия показывает прогресс, импульс (↗/→/↘), дедлайн и мини-статистику. Тап — вход в детали.» |
| 4 | MissionDetailScreen | `_ViewToggle` (`mission_detail_screen.dart:274`) | Список / Карта | «Внутри миссии два режима: „Список" — иерархия подцелей и задач, „Карта" — визуальный граф (Tactical Map).» |
| 5 | MissionDetailScreen | `_SubGoalsSection` header (`:758`) | Подцели и Fog of War | «Миссия разбивается на подцели (этапы). Fog of War скрывает будущие этапы — разблокируйте их по мере готовности.» |
| 6 | MissionDetailScreen | `_TaskTile` checkbox area (`:1176`) | Задачи | «Задачи — конкретные шаги. Отмечайте чекбоксом, назначайте вес (важность), связывайте зависимости.» |
| 7 | MissionDetailScreen | AI Decompose button (`:253`) | AI-декомпозиция | «Нажмите — AI разобьёт вашу миссию на подцели, задачи и вехи автоматически. Требуется согласие на обработку.» |
| 8 | MissionDetailScreen | `_QuickEntryBar` (`:169`) | Быстрый ввод | «Строка внизу — мгновенное добавление подцели, задачи или вехи без открытия меню. Переключайте тип слева.» |
| 9 | TacticalMapView | `_GoalNode` (`tactical_map_view.dart:1986`) + tool column (`:2029`) | Tactical Map | «Визуальный граф вашей миссии. Перетаскивайте ноды, добавляйте заметки/картинки/коннекторы. Справа — инструменты: поиск, зум, автокомпоновка.» |
| 10 | TacticalMapView | `_EditModeButton` (`:2128`) | Режим редактирования | «Нажмите, чтобы включить редактирование карты: добавлять заметки, метки, картинки и связи прямо на холст.» |

> **Завершение:** карточка «КУРС ЗАВЕРШЁН» с кнопкой «К ОПЕРАЦИЯМ» → `markCourseSeen('planning')` + `SieHaptics.success()`. Опционально: кнопка «Удалить демо-миссию».

### Поведение
- На шагах 4-10 тур автоматически `Navigator.push` в `MissionDetailScreen` (первая миссия из списка) и переключает `_mapMode` на шагах 9-10.
- Перед переключением экрана — post-frame callback для замера позиции новой цели.
- Если цель не отрисована — пропуск шага с предупреждением в лог.

---

## 3. Логика

### 3.1. Расширение TourController

`TourController` получает поддержку нескольких курсов через enum `TourType { app, planning, habits, focus, breathing }`.

```dart
class TourState {
  final TourType type;
  final int currentIndex;
  final bool isActive;
  final bool isCompleting;
  final Map<String, GlobalKey> keys;
}
```

`start(TourType.planning)` загружает steps для Planning-курса. Шаги хранятся в статических списках per-type.

### 3.2. Навигация между экранами

В отличие от общего тура (переключение вкладок), Planning-курс требует `Navigator.push`:
- Шаг 1-3: на `PlanningScreen`
- Шаг 4-8: `Navigator.push(MissionDetailScreen(goal: firstGoal))`
- Шаг 9-10: переключить `_mapMode = true` внутри MissionDetail

`TourController` хранит `BuildContext` (через `navigatorKey`) и выполняет push/pop. После завершения — `popUntil` до PlanningScreen.

### 3.3. Демонстрационная миссия

```dart
if (goals.isEmpty) {
  final demoGoal = await ref.read(goalsProvider.notifier).addGoal(
    name: 'Операция: Демо', colorHex: '#C8A84B',
  );
  // использовать demoGoal для шагов 4-10
}
```

### 3.4. Добавление GlobalKey к целям

| Цель | Файл | Изменение |
|------|------|-----------|
| FAB | `planning_screen.dart:93` | `key: tourKey('planning_fab')` |
| `_ModeSwitch` | `planning_screen.dart:117` | `key: tourKey('planning_mode_switch')` |
| Первый `_GoalCard` arc | `planning_screen.dart:749` | `key: tourKey('planning_goal_arc')` (только для первого card) |
| `_ViewToggle` | `mission_detail_screen.dart:274` | `key: tourKey('md_view_toggle')` |
| `_SubGoalsSection` header | `mission_detail_screen.dart:758` | `key: tourKey('md_subgoals_header')` |
| `_TaskTile` checkbox | `mission_detail_screen.dart:1176` | `key: tourKey('md_task_checkbox')` (первая задача) |
| AI Decompose button | `mission_detail_screen.dart:253` | `key: tourKey('md_ai_button')` |
| `_QuickEntryBar` | `mission_detail_screen.dart:169` | `key: tourKey('md_quick_entry')` |
| `_GoalNode` | `tactical_map_view.dart:1986` | `key: tourKey('tm_goal_node')` |
| Tool column | `tactical_map_view.dart:2029` | `key: tourKey('tm_tools')` |
| `_EditModeButton` | `tactical_map_view.dart:2128` | `key: tourKey('tm_edit_mode')` |

### 3.5. Флаг `hasSeenCoursePlanning`

- `Profile` model: `final bool hasSeenCoursePlanning;` (default false)
- JSON-ключ: `has_seen_course_planning`
- Миграция: `alter table profiles add column if not exists has_seen_course_planning boolean not null default false;`
- `user_profile_provider.dart`: `markCourseSeen('planning')` — generic-метод для всех курсов.

### 3.6. Запуск

В `PlanningScreen.initState`:
```dart
if (!profile.hasSeenCoursePlanning) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(tourControllerProvider.notifier).start(TourType.planning);
  });
}
```

---

## 4. Модули (затрагиваемые файлы)

### Новые файлы
| Файл | Назначение |
|------|-----------|
| `packages/sie_core/lib/i18n/ru/course_planning.i18n.json` | Локализация шагов курса |
| `packages/sie_core/lib/i18n/en/course_planning.i18n.json` | Английская локализация |
| `supabase/migrations/20260627110000_course_planning_flag.sql` | Колонка `has_seen_course_planning` |

### Изменяемые файлы
| Файл | Изменение |
|------|-----------|
| `packages/sie_core/lib/src/providers/tour_controller.dart` | Добавить `TourType.planning`, steps, навигация через push |
| `packages/sie_core/lib/src/models/profile.dart` | `hasSeenCoursePlanning` + JSON-маппинг |
| `packages/sie_core/lib/src/providers/user_profile_provider.dart` | `markCourseSeen(type)` |
| `supabase/schema.sql` | Колонка `has_seen_course_planning` |
| `apps/central_hub/lib/screens/planning_screen.dart` | `tourKey()` к FAB, ModeSwitch, первому GoalCard; автозапуск курса |
| `apps/central_hub/lib/screens/mission_detail_screen.dart` | `tourKey()` к ViewToggle, SubGoalsSection, TaskTile, AI button, QuickEntryBar |
| `apps/central_hub/lib/screens/tactical_map_view.dart` | `tourKey()` к GoalNode, tool column, EditModeButton |
| `apps/central_hub/lib/screens/profile_screen.dart` | Пункт «Курс: Planning» |

---

## 5. Схема данных

### Supabase `profiles`
```sql
-- 20260627110000_course_planning_flag.sql
alter table profiles
  add column if not exists has_seen_course_planning boolean not null default false;
```

### Drift
Без изменений — флаг в `cachedJson`.

### `TourStep` (in-memory)
```dart
class TourStep {
  final String id;
  final TourScreen screen;       // planning / missionDetail / tacticalMap
  final String targetKey;
  final String titleKey;         // 'course.planning.step1.title'
  final String bodyKey;
  final TargetPosition position;
}
```

---

## 6. Локализация (i18n)

### `course_planning.i18n.json` (ru)
```json
{
  "step1": { "title": "Создание миссии", "body": "Миссия — ваша главная цель. Нажмите +, чтобы создать новую: с нуля, из шаблона или через AI." },
  "step2": { "title": "Повестка / Цели", "body": "„Повестка" — стратегический обзор дня. „Цели" — список миссий с прогрессом и импульсом." },
  "step3": { "title": "Карточка миссии", "body": "Прогресс, импульс (↗/→/↘), дедлайн и мини-статистика. Тап — вход внутрь миссии." },
  "step4": { "title": "Список / Карта", "body": "Внутри миссии: „Список" — иерархия подцелей и задач. „Карта" — визуальный граф." },
  "step5": { "title": "Подцели и Fog of War", "body": "Миссия разбивается на этапы. Fog of War скрывает будущие этапы — разблокируйте по мере готовности." },
  "step6": { "title": "Задачи", "body": "Задачи — конкретные шаги. Отмечайте чекбоксом, задавайте вес, связывайте зависимости." },
  "step7": { "title": "AI-декомпозиция", "body": "AI автоматически разобьёт миссию на подцели, задачи и вехи. Требуется согласие на обработку." },
  "step8": { "title": "Быстрый ввод", "body": "Строка внизу — мгновенное добавление подцели, задачи или вехи. Переключайте тип слева." },
  "step9": { "title": "Tactical Map", "body": "Визуальный граф миссии. Перетаскивайте ноды, добавляйте заметки и связи. Справа — инструменты." },
  "step10": { "title": "Режим редактирования", "body": "Включите, чтобы добавлять на холст заметки, метки, картинки и коннекторы." },
  "complete": { "title": "КУРС ЗАВЕРШЁН", "body": "Вы освоили модуль Planning. Удачи в операциях, оперативник." },
  "actions": { "next": "ДАЛЕЕ", "back": "НАЗАД", "skip": "Пропустить", "finish": "К ОПЕРАЦИЯМ", "deleteDemo": "Удалить демо-миссию", "step": "Шаг {n} из {total}" }
}
```

---

## 7. Вопросы к обсуждению

1. **Демо-миссия:** создавать автоматически при 0 миссий (рекомендую) или показывать шаг 1 как инструкцию без создания?
2. **Глубина Tactical Map:** показывать шаги 9-10 (редактирование карты) всем или только после базовых шагов 1-8?
3. **AI-декомпозиция (шаг 7):** достаточно подсветить кнопку, или запускать реальный preview-вызов AI в демо-миссии?
4. **Удаление демо-миссии:** в финальной карточке дать кнопку «Удалить демо» или оставить миссию пользователю?
5. **Порядок:** сначала общий тур по приложению, потом курсы по модулям — или курсы доступны независимо в любой момент?