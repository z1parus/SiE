# План: Интерактивный курс по модулю Habit Tracker (Habit Matrix Tour)

> **Цель:** Обучить пользователя модулю привычек — созданию, типам (binary/count/duration), полярности (build/avoid), рутинам, свайпам, аналитике и журналу — через интерактивный overlay-курс.

**Режим:** Планирование → Реализация
**Формат:** Интерактивный тур (coach marks) — переиспользует `CoachMarkOverlay` + `TourController`.

---

## 1. Описание

Habit Tracker («Матрица привычек») — второй по сложности модуль. Новички не понимают разницу между типами привычек, не знают про свайпы (pin/delete), рутины (morning/evening/stack), rest-дни и журнал. Курс проводит по `HabitTrackerScreen` → `HabitDetailScreen` → `HabitsOverviewScreen`.

### Принципы
- **Требует наличия хотя бы одной привычки** — если 0, шаг 1 создаёт демо-привычку «Пить воду» (binary, health).
- **Свайпы** — на шаге с карточкой курса визуально демонстрируется swipe-жест анимацией (без реального выполнения).
- **Переиспользование инфраструктуры** — `TourController` + `CoachMarkOverlay`.
- **Киберпанк-стиль** — gold accent, letterSpacing 2.5.

---

## 2. Сценарий

### Точка запуска
Из `ProfileScreen` → «Курс: Привычки» или автоматически при первом входе в `HabitTrackerScreen` (флаг `hasSeenCourseHabits`).

> **Важно:** в `habit_tracker_screen.dart` уже есть `OnboardingOverlay` (полноэкранная карточка, `:361-377`). Курс заменяет его на coach-marks тур. Существующий `OnboardingOverlay` оставить как fallback / для повторного вызова через help-кнопку.

### Шаги курса (9 шагов)

| # | Экран | Цель (GlobalKey) | Заголовок | Суть |
|---|-------|------------------|-----------|------|
| 1 | HabitTracker | FAB (`habit_tracker_screen.dart:782`) | Создание привычки | «Привычка — протокол поведения. Нажмите +, чтобы создать: вручную или из библиотеки шаблонов.» |
| 2 | HabitTracker | `_ViewModeToggle` (`:165`) | Режимы просмотра | «Сегодня / Неделя / За всё время. Сегодня — дневная матрица, Неделя — 7-дневная полоса, Всё время — тепловая карта.» |
| 3 | HabitTracker | Первая `_SwipeableHabitCard` (`:242`) | Карточка привычки | «Отметьте выполнение тапом по карточке. Свайп вправо — закрепить (pin), влево — удалить. Стрик показан справа.» |
| 4 | HabitTracker | `_RoutineBlock` morning (`:137`) | Рутины | «Утренние и вечерние рутины объединяют привычки в последовательности. Создайте через кнопки снизу.» |
| 5 | HabitTracker | `_BottomActionBar` evening btn (`:784`) | Стеки привычек | «Помимо morning/evening есть „стеки" — named-рутины с привязкой к триггеру (anchor cue). Создайте через центральную кнопку.» |
| 6 | HabitDetail | Stats strip (`:4899`) | Статистика | «Стрик, сегодняшнее выполнение, заморозки (freeze), всего выполнено. Заморозки не ломают стрик.» |
| 7 | HabitDetail | `_HabitAnalyticsSection` heatmap (`:5657`) | Аналитика | «Тепловая карта за 16 недель или год. Инсайты: процент за 7/30 дней, рекорд, лучший/худший день недели.» |
| 8 | HabitDetail | Journal timeline (`:5231`) | Журнал | «К каждой отметке можно добавить заметку и эмодзи. Журнал внизу — история ваших рефлексий.» |
| 9 | HabitsOverview | `_RateCard` week (`habits_overview_screen.dart:79`) | Обзор | «Экран обзора: процент выполнения за неделю/месяц, общая тепловая карта, лидеры и проседающие привычки.» |

> **Завершение:** карточка «КУРС ЗАВЕРШЁН» → `markCourseSeen('habits')` + `SieHaptics.success()`. Опционально: «Удалить демо-привычку».

### Поведение
- Шаги 1-5: на `HabitTrackerScreen`.
- Шаги 6-8: `Navigator.push(HabitDetailScreen(habit: firstHabit))`.
- Шаг 9: `Navigator.push(HabitsOverviewScreen())`.
- После завершения — `popUntil` до HabitTrackerScreen.

---

## 3. Логика

### 3.1. Демонстрационная привычка

```dart
if (habits.isEmpty) {
  await ref.read(habitsProvider.notifier).addHabit(
    name: 'Пить воду', kind: 'binary', polarity: 'build',
    area: 'health', schedule: 'daily',
  );
}
```

### 3.2. Добавление GlobalKey к целям

| Цель | Файл | Изменение |
|------|------|-----------|
| FAB (center button) | `habit_tracker_screen.dart:751` | `key: tourKey('habits_fab')` |
| `_ViewModeToggle` | `habit_tracker_screen.dart:165` | `key: tourKey('habits_view_toggle')` |
| Первая `_SwipeableHabitCard` | `habit_tracker_screen.dart:242` | `key: tourKey('habits_first_card')` (только первая) |
| Morning `_RoutineBlock` | `habit_tracker_screen.dart:137` | `key: tourKey('habits_morning_routine')` |
| Evening side button | `habit_tracker_screen.dart:784` | `key: tourKey('habits_evening_btn')` |
| Stats strip | `habit_tracker_screen.dart:4899` | `key: tourKey('hd_stats')` |
| Heatmap | `habit_tracker_screen.dart:5657` | `key: tourKey('hd_heatmap')` |
| Journal timeline | `habit_tracker_screen.dart:5231` | `key: tourKey('hd_journal')` |
| Week `_RateCard` | `habits_overview_screen.dart:79` | `key: tourKey('ho_week_rate')` |

### 3.3. Демонстрация свайпа (шаг 3)

На шаге 3 поверх карточки показывается анимированная рука/стрелка, имитирующая swipe-right (pin) и swipe-left (delete) — через `AnimatedPositioned` / `AnimatedRotation`. Не выполняет реального действия. 2-секундная анимация, повторяется 2 раза.

### 3.4. Флаг `hasSeenCourseHabits`

- `Profile` model: `final bool hasSeenCourseHabits;`
- JSON-ключ: `has_seen_course_habits`
- Миграция: `alter table profiles add column if not exists has_seen_course_habits boolean not null default false;`

### 3.5. Запуск

В `HabitTrackerScreen.initState` (после существующей логики onboarding):
```dart
if (!profile.hasSeenCourseHabits && profile.hasSeenOnboardingHabits) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(tourControllerProvider.notifier).start(TourType.habits);
  });
}
```
> Запуск курса после закрытия существующего `OnboardingOverlay`, чтобы не накладывались.

---

## 4. Модули (затрагиваемые файлы)

### Новые файлы
| Файл | Назначение |
|------|-----------|
| `packages/sie_core/lib/i18n/ru/course_habits.i18n.json` | Локализация |
| `packages/sie_core/lib/i18n/en/course_habits.i18n.json` | Английская |
| `supabase/migrations/20260627120000_course_habits_flag.sql` | Колонка |

### Изменяемые файлы
| Файл | Изменение |
|------|-----------|
| `packages/sie_core/lib/src/providers/tour_controller.dart` | `TourType.habits`, steps, навигация |
| `packages/sie_core/lib/src/models/profile.dart` | `hasSeenCourseHabits` |
| `packages/sie_core/lib/src/providers/user_profile_provider.dart` | `markCourseSeen('habits')` |
| `supabase/schema.sql` | Колонка |
| `apps/central_hub/lib/screens/habit_tracker_screen.dart` | `tourKey()` к целям; автозапуск |
| `apps/central_hub/lib/screens/habits_overview_screen.dart` | `tourKey()` к RateCard |
| `apps/central_hub/lib/screens/profile_screen.dart` | Пункт «Курс: Привычки» |

---

## 5. Схема данных

```sql
-- 20260627120000_course_habits_flag.sql
alter table profiles
  add column if not exists has_seen_course_habits boolean not null default false;
```

---

## 6. Локализация (i18n)

### `course_habits.i18n.json` (ru)
```json
{
  "step1": { "title": "Создание привычки", "body": "Привычка — протокол поведения. Нажмите +: вручную или из библиотеки шаблонов." },
  "step2": { "title": "Режимы просмотра", "body": "Сегодня — дневная матрица. Неделя — 7-дневная полоса. Всё время — тепловая карта." },
  "step3": { "title": "Карточка привычки", "body": "Тап — отметить выполнение. Свайп вправо — закрепить. Свайп влево — удалить. Стрик справа." },
  "step4": { "title": "Рутины", "body": "Утренние и вечерние рутины объединяют привычки в последовательности. Создайте через кнопки снизу." },
  "step5": { "title": "Стеки", "body": "Named-рутины с привязкой к триггеру (anchor cue). Создайте через центральную кнопку." },
  "step6": { "title": "Статистика", "body": "Стрик, сегодняшнее выполнение, заморозки (не ломают стрик), всего выполнено." },
  "step7": { "title": "Аналитика", "body": "Тепловая карта 16 недель или год. Инсайты: процент, рекорд, лучший/худший день." },
  "step8": { "title": "Журнал", "body": "К каждой отметке — заметка и эмодзи. Журнал — история ваших рефлексий." },
  "step9": { "title": "Обзор", "body": "Процент за неделю/месяц, общая карта, лидеры и проседающие привычки." },
  "complete": { "title": "КУРС ЗАВЕРШЁН", "body": "Матрица привычек освоена. Дисциплина — ваш фундамент." },
  "actions": { "next": "ДАЛЕЕ", "back": "НАЗАД", "skip": "Пропустить", "finish": "ГОТОВО", "deleteDemo": "Удалить демо-привычку", "step": "Шаг {n} из {total}" }
}
```

---

## 7. Вопросы к обсуждению

1. **Демо-привычка:** создавать «Пить воду» (рекомендую) или оставлять пользователя без привычек и показывать пустое состояние?
2. **Свайп-анимация (шаг 3):** анимированная рука/стрелка (рекомендую) или просто текст «Свайпните карточку»?
3. **Rest-день:** включить отдельный шаг про rest-дни (кнопка снежинки в деталях) или объединить со шагом 6 (статистика)?
4. **Avoid-привычки:** показывать отдельный шаг про «ломать вредную» или это слишком для базового курса?
5. **Существующий OnboardingOverlay:** заменить на курс или оставить оба (overlay → курс)?