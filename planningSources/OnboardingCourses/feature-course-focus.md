# План: Интерактивный курс по модулю Focus Protocol (Chrono-Ring Tour)

> **Цель:** Обучить пользователя модулю фокусировки — таймеру Pomodoro, привязке к задачам, настройкам длительности, ставке XP и результату сессии — через интерактивный overlay-курс.

**Режим:** Планирование → Реализация
**Формат:** Интерактивный тур (coach marks) — переиспользует `CoachMarkOverlay` + `TourController`.

---

## 1. Описание

Focus Protocol («Chrono-Ring») — Pomodoro-таймер глубокого труда. Новички не понимают, как связать сессию с задачей, как настроить длительность, что такое stake XP и что происходит по завершении. Курс проводит по `FocusProtocolScreen`.

### Принципы
- **Один экран** — весь курс на `FocusProtocolScreen`, без навигации.
- **Не запускает таймер** — курс объясняет UI, но не начинает реальную сессию.
- **Переиспользование инфраструктуры** — `TourController` + `CoachMarkOverlay`.
- **Киберпанк-стиль** — gold accent.

---

## 2. Сценарий

### Точка запуска
Из `ProfileScreen` → «Курс: Фокус» или автоматически при первом входе в `FocusProtocolScreen` (флаг `hasSeenCourseFocus`).

> Существующий `OnboardingOverlay` (`focus_protocol_screen.dart:211-227`) — оставить как fallback. Курс запускается после его закрытия.

### Шаги курса (6 шагов)

| # | Экран | Цель (GlobalKey) | Заголовок | Суть |
|---|-------|------------------|-----------|------|
| 1 | FocusProtocol | `_FocusRing` (`focus_protocol_screen.dart:236`) | Chrono-Ring | «Кольцо таймера показывает время до конца фазы. Фаза FOCUS — глубокая работа, BREAK — отдых.» |
| 2 | FocusProtocol | `_BottomHUD` phase label (`:506`) | Фазы | «FOCUS — время концентрации (по умолчанию 25 мин). BREAK — перерыв (5 мин). Циклы повторяются.» |
| 3 | FocusProtocol | `_BottomHUD` XP value (`:544`) | Ставка XP | «За каждую фокус-сессию вы получаете XP (по умолчанию 100). Прерывание — частичный XP после 30 секунд.» |
| 4 | FocusProtocol | `_FocusTaskBanner` area (`:382`) | Привязка задачи | «Опционально: привяжите сессию к задаче из Planning. Время фокус-сессии зачислится в аналитику задачи.» |
| 5 | FocusProtocol | `_SettingsButton` (`:580`) | Настройки | «Настройте длительность фокуса (5-60 мин) и перерыва (1-15 мин), фоновую музыку для фокуса и отдыха.» |
| 6 | FocusProtocol | Start/Pause button (`:588`) | Старт | «Нажмите START, чтобы начать фокус-сессию. Во время сессии — PAUSE/RESUME. RESET — сброс.» |

> **Завершение:** карточка «КУРС ЗАВЕРШЁН» → `markCourseSeen('focus')` + `SieHaptics.success()`.

### Поведение
- Все шаги на одном экране, без навигации.
- Если `_FocusTaskBanner` не отрисован (нет привязанной задачи) — шаг 4 показывает текст без подсветки (overlay в центре экрана).

---

## 3. Логика

### 3.1. Добавление GlobalKey к целям

| Цель | Файл | Изменение |
|------|------|-----------|
| `_FocusRing` | `focus_protocol_screen.dart:236` | `key: tourKey('focus_ring')` |
| Phase label | `focus_protocol_screen.dart:506` | `key: tourKey('focus_phase')` |
| XP value | `focus_protocol_screen.dart:544` | `key: tourKey('focus_xp')` |
| `_FocusTaskBanner` area | `focus_protocol_screen.dart:382` | `key: tourKey('focus_task_banner')` |
| `_SettingsButton` | `focus_protocol_screen.dart:580` | `key: tourKey('focus_settings')` |
| Start/Pause button | `focus_protocol_screen.dart:588` | `key: tourKey('focus_start')` |

### 3.2. Флаг `hasSeenCourseFocus`

- `Profile` model: `final bool hasSeenCourseFocus;`
- JSON-ключ: `has_seen_course_focus`
- Миграция: `alter table profiles add column if not exists has_seen_course_focus boolean not null default false;`

### 3.3. Запуск

В `FocusProtocolScreen.initState` (после onboarding logic):
```dart
if (!profile.hasSeenCourseFocus && profile.hasSeenOnboardingFocus) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(tourControllerProvider.notifier).start(TourType.focus);
  });
}
```

---

## 4. Модули (затрагиваемые файлы)

### Новые файлы
| Файл | Назначение |
|------|-----------|
| `packages/sie_core/lib/i18n/ru/course_focus.i18n.json` | Локализация |
| `packages/sie_core/lib/i18n/en/course_focus.i18n.json` | Английская |
| `supabase/migrations/20260627130000_course_focus_flag.sql` | Колонка |

### Изменяемые файлы
| Файл | Изменение |
|------|-----------|
| `packages/sie_core/lib/src/providers/tour_controller.dart` | `TourType.focus`, steps |
| `packages/sie_core/lib/src/models/profile.dart` | `hasSeenCourseFocus` |
| `packages/sie_core/lib/src/providers/user_profile_provider.dart` | `markCourseSeen('focus')` |
| `supabase/schema.sql` | Колонка |
| `apps/central_hub/lib/screens/focus_protocol_screen.dart` | `tourKey()` к целям; автозапуск |
| `apps/central_hub/lib/screens/profile_screen.dart` | Пункт «Курс: Фокус» |

---

## 5. Схема данных

```sql
-- 20260627130000_course_focus_flag.sql
alter table profiles
  add column if not exists has_seen_course_focus boolean not null default false;
```

---

## 6. Локализация (i18n)

### `course_focus.i18n.json` (ru)
```json
{
  "step1": { "title": "Chrono-Ring", "body": "Кольцо таймера — обратный отсчёт фазы. FOCUS — глубокая работа, BREAK — отдых." },
  "step2": { "title": "Фазы", "body": "FOCUS — концентрация (25 мин по умолчанию). BREAK — перерыв (5 мин). Циклы повторяются." },
  "step3": { "title": "Ставка XP", "body": "За фокус-сессию — XP (100 по умолчанию). Прерывание после 30 сек — частичный XP." },
  "step4": { "title": "Привязка задачи", "body": "Опционально: привяжите сессию к задаче из Planning. Время зачислится в аналитику задачи." },
  "step5": { "title": "Настройки", "body": "Длительность фокуса (5-60 мин) и перерыва (1-15 мин), фоновая музыка для каждой фазы." },
  "step6": { "title": "Старт", "body": "START — начать сессию. PAUSE/RESUME — пауза. RESET — сброс. По завершении — экран награды." },
  "complete": { "title": "КУРС ЗАВЕРШЁН", "body": "Chrono-Ring готов к работе. Глубокий труд — ваш козырь." },
  "actions": { "next": "ДАЛЕЕ", "back": "НАЗАД", "skip": "Пропустить", "finish": "ГОТОВО", "step": "Шаг {n} из {total}" }
}
```

---

## 7. Вопросы к обсуждению

1. **Привязка задачи (шаг 4):** показывать только если есть активные задачи, или всегда (как концепция)?
2. **Result overlay:** включить шаг про экран награды (показать скриншот) или достаточно текста в шаге 3?
3. **Количество шагов:** 6 — нормально, или сократить до 4 (убрать фазы + привязку)?
4. **Запуск курса:** после существующего OnboardingOverlay (рекомендую) или вместо него?