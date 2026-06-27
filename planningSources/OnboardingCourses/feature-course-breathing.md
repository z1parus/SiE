# План: Интерактивный курс по модулю Breathing (Breathing Sphere Tour)

> **Цель:** Обучить пользователя модулю дыхательных практик — визуализатору сферы, протоколу Вима Хоф, настройкам раундов/циклов, звуку и завершению сессии — через интерактивный overlay-курс.

**Режим:** Планирование → Реализация
**Формат:** Интерактивный тур (coach marks) — переиспользует `CoachMarkOverlay` + `TourController`.

---

## 1. Описание

Breathing Exercise — дыхательный протокол с GLSL-шейдерной сферой. Новички не понимают структуру протокола (раунды → циклы → задержки), не знают про настройки звука и пресеты. Курс проводит по `BreathingExerciseScreen`.

### Принципы
- **Один экран** — весь курс на `BreathingExerciseScreen`, без навигации.
- **Не запускает сессию** — курс объясняет UI, но не начинает реальный протокол.
- **Переиспользование инфраструктуры** — `TourController` + `CoachMarkOverlay`.
- **Киберпанк-стиль** — gold accent.

---

## 2. Сценарий

### Точка запуска
Из `ProfileScreen` → «Курс: Дыхание» или автоматически при первом входе в `BreathingExerciseScreen` (флаг `hasSeenCourseBreathing`).

> Существующий `OnboardingOverlay` (`breathing_exercise_screen.dart:898-914`) — оставить как fallback. Курс запускается после его закрытия.

### Шаги курса (6 шагов)

| # | Экран | Цель (GlobalKey) | Заголовок | Суть |
|---|-------|------------------|-----------|------|
| 1 | Breathing | Sphere (`breathing_exercise_screen.dart:920`) | Сфера | «Сфера расширяется на вдохе и сжимается на выдохе. Дышите в ритме сферы. Тап по сфере — начать.» |
| 2 | Breathing | HUD card title/rounds (`:1054`) | Протокол | «Протокол: раунды (по умолчанию 3), циклы вдох-выдох в каждом раунде, затем задержка дыхания (retention).» |
| 3 | Breathing | Active phase label area (`:1148`) | Фазы дыхания | «INHALE — вдох, EXHALE — выдох. После циклов — HOLD (задержка). Кнопка RELEASE — закончить задержку досрочно.» |
| 4 | Breathing | `_SettingsButton` (`:1096`) | Настройки | «Настройте раунды, циклы, длительности вдоха/выдоха/задержки. Звук: ambient, дыхание, heartbeat, тики. Громкость по каналам.» |
| 5 | Breathing | Journal/Stats buttons in `_TopBar` (`:1628`, `:1630`) | Журнал и статистика | «Журнал — история сессий. Статистика — графики и инсайты по дыхательным практикам.» |
| 6 | Breathing | Initiate button (`:1102`) | Старт | «Нажмите INITIATE PROTOCOL, чтобы начать. Отсчёт 5 секунд → дыхательные циклы → задержка → завершение.» |

> **Завершение:** карточка «КУРС ЗАВЕРШЁН» → `markCourseSeen('breathing')` + `SieHaptics.success()`.

### Поведение
- Все шаги на одном экране, без навигации.
- Фаза UI = idle для всех шагов (тур не запускает сессию). Подсветка элементов idle-состояния: сфера, HUD-карточка, settings, initiate button.
- Шаги 3 (фазы) и 5 (журнал) — объясняют концепции, которые видны только во время/после сессии; показываются как текст с иконкой-иллюстрацией в overlay (без подсветки живого элемента, т.к. в idle их нет).

---

## 3. Логика

### 3.1. Добавление GlobalKey к целям

| Цель | Файл | Изменение |
|------|------|-----------|
| Sphere GestureDetector | `breathing_exercise_screen.dart:840` | `key: tourKey('breathing_sphere')` |
| HUD card | `breathing_exercise_screen.dart:1054` | `key: tourKey('breathing_hud')` |
| Active phase label | `breathing_exercise_screen.dart:1148` | `key: tourKey('breathing_phase')` (only visible when active; fallback overlay center) |
| `_SettingsButton` | `breathing_exercise_screen.dart:1096` | `key: tourKey('breathing_settings')` |
| Journal button | `breathing_exercise_screen.dart:1628` | `key: tourKey('breathing_journal')` |
| Stats button | `breathing_exercise_screen.dart:1630` | `key: tourKey('breathing_stats')` |
| Initiate button | `breathing_exercise_screen.dart:1102` | `key: tourKey('breathing_initiate')` |

### 3.2. Флаг `hasSeenCourseBreathing`

- `Profile` model: `final bool hasSeenCourseBreathing;`
- JSON-ключ: `has_seen_course_breathing`
- Миграция: `alter table profiles add column if not exists has_seen_course_breathing boolean not null default false;`

### 3.3. Запуск

В `BreathingExerciseScreen.initState` (после onboarding logic):
```dart
if (!profile.hasSeenCourseBreathing && profile.hasSeenOnboardingBreathing) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(tourControllerProvider.notifier).start(TourType.breathing);
  });
}
```

---

## 4. Модули (затрагиваемые файлы)

### Новые файлы
| Файл | Назначение |
|------|-----------|
| `packages/sie_core/lib/i18n/ru/course_breathing.i18n.json` | Локализация |
| `packages/sie_core/lib/i18n/en/course_breathing.i18n.json` | Английская |
| `supabase/migrations/20260627140000_course_breathing_flag.sql` | Колонка |

### Изменяемые файлы
| Файл | Изменение |
|------|-----------|
| `packages/sie_core/lib/src/providers/tour_controller.dart` | `TourType.breathing`, steps |
| `packages/sie_core/lib/src/models/profile.dart` | `hasSeenCourseBreathing` |
| `packages/sie_core/lib/src/providers/user_profile_provider.dart` | `markCourseSeen('breathing')` |
| `supabase/schema.sql` | Колонка |
| `apps/central_hub/lib/screens/breathing_exercise_screen.dart` | `tourKey()` к целям; автозапуск |
| `apps/central_hub/lib/screens/profile_screen.dart` | Пункт «Курс: Дыхание» |

---

## 5. Схема данных

```sql
-- 20260627140000_course_breathing_flag.sql
alter table profiles
  add column if not exists has_seen_course_breathing boolean not null default false;
```

---

## 6. Локализация (i18n)

### `course_breathing.i18n.json` (ru)
```json
{
  "step1": { "title": "Сфера", "body": "Сфера расширяется на вдохе, сжимается на выдохе. Дышите в ритме. Тап по сфере — начать." },
  "step2": { "title": "Протокол", "body": "Раунды (3 по умолчанию), циклы вдох-выдох в каждом, затем задержка дыхания (retention)." },
  "step3": { "title": "Фазы", "body": "INHALE — вдох, EXHALE — выдох, HOLD — задержка. RELEASE — закончить задержку досрочно." },
  "step4": { "title": "Настройки", "body": "Раунды, циклы, длительности. Звук: ambient, дыхание, heartbeat, тики. Громкость по каналам." },
  "step5": { "title": "Журнал и статистика", "body": "Журнал — история сессий. Статистика — графики и инсайты по практикам." },
  "step6": { "title": "Старт", "body": "INITIATE PROTOCOL — начать. Отсчёт 5 сек → циклы → задержка → завершение и рефлексия." },
  "complete": { "title": "КУРС ЗАВЕРШЁН", "body": "Дыхательный протокол освоен. Спокойствие — ваша сила." },
  "actions": { "next": "ДАЛЕЕ", "back": "НАЗАД", "skip": "Пропустить", "finish": "ГОТОВО", "step": "Шаг {n} из {total}" }
}
```

---

## 7. Вопросы к обсуждению

1. **Пресеты:** включить шаг про save/load пресеты в настройках или это слишком детально для базового курса?
2. **Sequences:** отдельный шаг про «Мои последовательности» (custom per-round params) или опустить?
3. **Recovery/Reflection экран:** упомянуть в шаге 6 (текст) или отдельный шаг с навигацией?
4. **Шаг 3 (фазы):** в idle элементы фаз не видны — показывать overlay-иллюстрацию в центре (рекомендую) или пропустить шаг?
5. **Количество шагов:** 6 — нормально, или сократить до 4?