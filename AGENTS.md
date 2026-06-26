# SiE — AGENTS.md (Инструкции для AI-агентов)

> **SiE (System in Evolution)** — экосистема для саморазвития в эстетике «киберпанк-оперативного штаба». Приложение превращает дисциплину и личностный рост в геймифицированный процесс: привычки — протоколы, цели — тактические миссии.

- **Репозиторий:** https://github.com/z1parus/SiE.git
- **GitHub-аккаунт:** `z1parus`
- **Текущая версия приложения:** `2.7.16+37` (см. `apps/central_hub/pubspec.yaml`)
- **Цель релиза:** v1.0 к 31 июля 2026 г. (см. `planningSources/PLANNING.md`)

---

## 1. Технологический стек

| Слой            | Технология                                                                 |
|-----------------|---------------------------------------------------------------------------|
| Frontend        | Flutter 3.32.3 / Dart 3.8.1 (кроссплатформа: Android, iOS, Web, macOS, Windows, Linux) |
| State Management| Riverpod (`flutter_riverpod` ^2.6.1)                                      |
| Local DB        | Drift (SQLite), кодогенерация через `build_runner` → `*.g.dart`           |
| Backend         | Supabase (PostgreSQL, Auth, Edge Functions, RLS, Storage)                 |
| Offline-first   | Локальный Drift-кеш → очередь `PendingSyncOps` → синхронизация с Supabase |
| CI/CD           | Codemagic (iOS unsigned IPA), GitHub Actions (релизы APK)                 |
| Web-деплой      | `deploy.sh` → GitHub Pages (`gh-pages`), https://z1parus.github.io/SiE/  |

### Окружение (remote-сервер)
- **Flutter SDK:** `/opt/flutter`
- **Android SDK:** `/opt/android` (`ANDROID_HOME`)
- **Supabase CLI:** залогинен, проект `bvqlqvzcqfgojzxztvrm` (West EU)
- **GitHub CLI:** залогинен как `z1parus`
- **Supabase URL:** `https://bvqlqvzcqfgojzxztvrm.supabase.co`
- **Supabase anon key:** задан в `apps/central_hub/lib/main.dart`

---

## 2. Структура проекта (Monorepo-lite)

```
SiE/
├── apps/central_hub/          # Основное Flutter-приложение
│   ├── lib/
│   │   ├── main.dart          # Точка входа, инициализация Supabase + NotificationService
│   │   ├── config.dart        # Внешние API-ключи (Groq)
│   │   ├── screens/           # ~40 экранов (см. раздел 3)
│   │   └── widgets/          # Локальные виджеты (heatmap, charts, sparkline, attachment_gallery)
│   ├── assets/
│   │   ├── audio/             # ambient.mp3, inhale.mp3, exhale.mp3, notification_end.mp3
│   │   ├── icons/             # app_icon, orb_splash (несколько разрешений)
│   │   └── shaders/           # breathing_sphere.frag (GLSL фрагментный шейдер)
│   ├── android/ ios/ macos/ windows/ linux/ web/   # Нативные платформы
│   └── pubspec.yaml           # version: 2.7.16+37
│
├── packages/
│   ├── sie_core/              # Общий пакет: бизнес-логика, модели, провайдеры, БД
│   │   ├── lib/
│   │   │   ├── sie_core.dart              # Баррел-экспорт ~93 модулей
│   │   │   ├── src/
│   │   │   │   ├── supabase_service.dart  # Инициализация + Auth (signUp/signIn/signOut/resetPassword/signInWithTelegram)
│   │   │   │   ├── local/app_database.dart  # Drift-БД: 26 таблиц, schemaVersion=35
│   │   │   │   ├── models/               # ~30 data-классов (Dart-модели)
│   │   │   │   ├── providers/            # ~30 Riverpod-провайдеров
│   │   │   │   ├── services/
│   │   │   │   │   ├── sync_service.dart  # Очередь синхронизации (offline → online)
│   │   │   │   │   ├── audio_service.dart # Аудио-движок для дыхания
│   │   │   │   │   ├── groq_service.dart  # AI-декомпозиция задач через Groq API
│   │   │   │   │   ├── goal_map_live_service.dart  # Realtime-коллаборация на Tactical Map
│   │   │   │   │   ├── notification_service.dart  # Локальные push-уведомления
│   │   │   │   │   └── connectivity_service.dart   # Мониторинг онлайна
│   │   │   │   ├── theme/                # SieTheme: classicDark / classicLight + SieColors, SieHaptics, SieMotion
│   │   │   │   ├── utils/                # fog_of_war, goal_markdown, color_utils, member_colors
│   │   │   │   └── widgets/               # Переиспользуемые UI-компоненты (glass_card, skeleton, empty_state, ...)
│   │   └── pubspec.yaml
│   └── soundpool/             # Форк пакета soundpool (dependency_override)
│
├── supabase/
│   ├── schema.sql             # Полная схема БД (~1000 строк, 14+ таблиц)
│   ├── config.toml            # Конфиг Supabase CLI
│   ├── migrations/           # 54 миграции (см. раздел 5)
│   └── functions/            # Edge Functions: ai-decompose, daily-winner, cleanup-attachment-storage, telegram-auth
│
├── planningSources/           # Вся техдокументация и планы (ТОЛЬКО .md файлы)
│   ├── PLANNING.md            # Стратегический roadmap до v1.0
│   ├── FOUNDBUGS.md           # История исправленных багов
│   ├── devPLANNING.md         # Текущий dev-план
│   ├── DesignPlanning/        # Дизайн-документы (ClassicLight, HabitCreation, ProfilePatterns, sfera)
│   ├── HabitModule/           # Спецификации модуля привычек
│   ├── HabitModuleEvolution/  # Roadmap эволюции привычек (9 этапов: 00-08)
│   ├── MeditationModule/      # Спецификации медитации (4 документа)
│   ├── PlanningModule/        # Спецификации Planning (9 документов)
│   ├── PlanningModuleEvolution/ # Roadmap эволюции планирования (10 этапов: 00-09)
│   ├── TacticalMapEvolution/  # Roadmap Tactical Map (9 этапов: 00-08)
│   ├── ThemeRedesign/         # План редизайна темы
│   ├── UserProfileDesignEvolution/
│   ├── ReleaseReports/        # Отчеты о релизах Planning Module (5 отчетов)
│   ├── UX-Audit/              # Аудит UX (7 документов)
│   └── *.md                   # Тематические планы: goal-collaboration, social-friends, tactical-map-*, performance-optimization, xp-anti-farming, ...
│
├── releases/                  # (пусто — релизы хранятся как APK в корне + GitHub Releases)
├── *.apk                      # Собранные APK: SiE-v1.x, SiE-Hub-v2.5.x, SiE-Hub-v2.7.x (36 файлов)
├── codemagic.yaml             # CI: iOS unsigned IPA build (mac_mini_m1)
├── deploy.sh                  # Web-деплой: flutter build web → gh-pages
├── CLAUDE.md                  # Инструкции для Claude (режим планирования + релиз)
├── GEMINI.md                  # Инструкции для Gemini (режим исследования + архитектура)
├── Knowledge.md               # Краткий knowledge ledger
├── README.md                  # Описание проекта
└── AGENTS.md                  # ← ЭТОТ ФАЙЛ
```

---

## 3. Ключевые экраны приложения (`apps/central_hub/lib/screens/`)

| Экран                               | Назначение                                                                 |
|-------------------------------------|---------------------------------------------------------------------------|
| `splash_screen.dart`                | Анимированный сплэш при запуске (орб)                                      |
| `auth_screen.dart`                  | Регистрация / вход (email + password или Telegram OAuth через Supabase Auth) |
| `main_navigation_shell.dart`        | Нижняя навигация: Hub, Operations, Garage, Hall of Fame                    |
| `operations_control_screen.dart`    | Главный дашборд: XP, уровень, активные департаменты                        |
| `planning_screen.dart`              | Planning Module: список миссий                                            |
| `mission_detail_screen.dart`        | Детали цели: подцели, задачи, вехи                                        |
| `tactical_map_view.dart`            | Интерактивный граф целей (drag-and-drop, fog of war, группы, коннекторы)   |
| `war_room_screen.dart`              | Военный зал: стратегический обзор                                         |
| `habit_tracker_screen.dart`         | Ежедневный трекер привычек                                                |
| `habits_overview_screen.dart`       | Обзор всех привычек + фильтры                                             |
| `habit_detail_screen.dart`          | Детали привычки: стрики, журнал, тепловая карта                           |
| `habit_library_screen.dart`         | Библиотека шаблонов привычек                                              |
| `routine_editor_screen.dart`        | Редактор рутин (утренние/вечерние/стеки)                                  |
| `focus_protocol_screen.dart`        | Таймер фокусировки (Pomodoro, глубокая работа)                            |
| `breathing_exercise_screen.dart`    | Дыхательные практики (Вима Хоф, визуализатор сферы, шейдеры)              |
| `meditation_hub_screen.dart`        | Хаб медитаций                                                             |
| `meditation_session_screen.dart`    | Сессия медитации                                                          |
| `meditation_preflight_screen.dart`  | Предстартовая настройка медитации                                         |
| `meditation_preset_builder_screen.dart` | Конструктор пресетов медитации                                       |
| `profile_screen.dart`               | Личный профиль: XP, уровень, награды, сейф медалей                         |
| `public_profile_screen.dart`        | Публичное досье оперативника                                              |
| `edit_profile_screen.dart`          | Редактирование профиля                                                    |
| `garage_screen.dart`                | Магазин визуальных улучшений (Design Points)                              |
| `customization_screen.dart`         | Настройка кастомизации                                                    |
| `leaderboard_screen.dart`           | Глобальный рейтинг «Авангард Суток»                                        |
| `user_search_screen.dart`           | Поиск пользователей                                                       |
| `friends_list_screen.dart`          | Список друзей                                                             |
| `knowledge_base_screen.dart`        | База знаний                                                               |
| `goal_stats_screen.dart`            | Аналитика по цели                                                         |
| `goal_export_sheet.dart`            | Экспорт целей                                                             |
| `progress_analytics_screen.dart`    | Аналитика прогресса                                                       |
| `weekly_review_screen.dart`         | Еженедельный обзор                                                        |
| `mission_accomplished_screen.dart`  | Экран завершения миссии (медали + XP-бонусы)                               |
| `reminder_settings_screen.dart`     | Настройки напоминаний                                                     |
| `template_gallery_screen.dart`      | Галерея шаблонов миссий                                                   |
| `ai_decomposition_sheet.dart`       | AI-декомпозиция задачи через Groq                                         |
| `milestone_metric_screen.dart`      | Метрики вех (количественные/бинарные)                                     |
| `session_orb_painters.dart`         | Custom painters для орба дыхания                                          |

---

## 4. Локальная база данных (Drift)

**Файл:** `packages/sie_core/lib/src/local/app_database.dart`
**Schema version:** 35 (миграции с try/catch fallback — при ошибке пересоздаёт схему)

### Таблицы (26 штук):

**Привычки:**
- `LocalHabits` — привычки (schedule, kind: binary/count/duration, polarity: build/avoid, area, reminderTime)
- `LocalHabitLogs` — логи выполнения (note, emoji, value, entryType: done/rest)
- `LocalRoutines` — рутины (morning/evening/stack, name, anchorCue)
- `LocalRoutineMembers` — элементы рутин

**Планирование:**
- `LocalGoals` — цели (status, progress, colorHex, isPinned, isShared, myRole, settingsJson)
- `LocalSubGoals` — подцели (иерархия, parentSubGoalId, orderIndex)
- `LocalPlanningTasks` — задачи (weight, dueDate, recurrenceRule, recurrenceParentId)
- `LocalMilestones` — вехи (kind: binary/metric, unit, startValue/targetValue/currentValue, direction)
- `LocalMilestoneLogs` — логи метрик вех
- `LocalMissionMedals` — медали миссий (Bronze/Silver/Gold, medalType: goal/...)
- `LocalMissionTemplates` — шаблоны миссий (isSystem, isPublic, structureJson)
- `LocalGoalHabitLinks` — связь целей с привычками (boostValue)
- `LocalTaskDependencies` — зависимости между задачами
- `LocalGoalProgressSnapshots` — снимки прогресса (dayKey — один в день на цель)
- `LocalWeeklyReviews` — еженедельные обзоры

**Tactical Map:**
- `LocalMapPositions` — позиции нод на канвасе (goalId, nodeId, x, y)
- `LocalMapElements` — элементы карты (kind: note/label/image/group/connector, content, mediaUrl, styleJsonText)
- `LocalNodeAttachments` — вложения к нодам (storagePath, localPath, mimeType)
- `LocalTaskAssignees` — исполнители задач
- `LocalSubGoalAssignees` — исполнители подцелей

**Сессии:**
- `LocalFocusSessions` — сессии фокусировки (durationSeconds, xpAwarded, dpAwarded, taskId, goalId)
- `LocalBreathingSessions` — сессии дыхания
- `LocalMeditationSessions` — сессии медитации (stateBefore/After, presetId)
- `LocalMeditationPresets` — пресеты медитации (breathingPatternId, meditationType, volumes, affirmationPackId)

**Профиль и синхронизация:**
- `LocalProfiles` — кеш профиля (totalXp, designPoints, pendingXp, pendingDp, cachedJson)
- `PendingSyncOps` — очередь операций (operationType, payload JSON, attempts, lastError)

---

## 5. Backend (Supabase)

### Схема БД (`supabase/schema.sql` + миграции)

**52 миграции** — эволюция от init_core_schema до fix_collab_rls_recursion.

> **Telegram OAuth (миграции `20260626200000_telegram_auth.sql` + `20260626210000_telegram_auth_codes.sql`, Edge Function `telegram-auth`):** Supabase Auth не поддерживает Telegram нативно, поэтому реализован Custom OAuth Provider `custom:telegram` через Edge Function-адаптер `supabase/functions/telegram-auth/index.ts`. Он оборачивает Telegram Login Widget в стандартный OAuth2 flow (`/authorize` → `/telegram-callback` → `/token` → `/userinfo`) и валидирует `hash` по алгоритму Telegram. Для активации: (1) создать бота через @BotFather → получить `bot_token`; (2) задать secrets в Edge Function: `TELEGRAM_BOT_TOKEN`, `JWT_SECRET` (= JWT secret проекта из Dashboard → Settings → API); (3) Dashboard → Authentication → Providers → New Provider → Manual: identifier `custom:telegram`, Client ID любой, Client Secret = bot_token, Authorization/Token/UserInfo URL = `https://bvqlqvzcqfgojzxztvrm.functions.supabase.co/telegram-auth/{authorize|token|userinfo}`; (4) включить **Email optional** (Advanced) — Telegram не отдаёт email; redirect URL `sie://auth/callback` и `https://bvqlqvzcqfgojzxztvrm.supabase.co/auth/v1/callback`.

Основные таблицы:
- `profiles` — профили пользователей (XP, DP, уровень, username, avatar_url, ...)
- `branches` — департаменты/филиалы
- `user_branches` — связь пользователей с филиалами
- `habits` — привычки
- `habit_logs` — логи привычек (UNIQUE: user_id, habit_id, completed_at)
- `focus_sessions` — сессии фокусировки
- `achievements` / `user_achievements` — достижения
- `goals` — цели (status, progress, settings JSON, is_pinned, is_shared)
- `sub_goals` — подцели
- `planning_tasks` — задачи (recurrence_rule, completed_at)
- `milestones` — вехи (kind, unit, target_value, direction)
- `goal_progress_snapshots` — снимки прогресса
- `mission_medals` — медали (Bronze/Silver/Gold)
- `mission_templates` — шаблоны миссий
- `goal_habit_links` — связь целей и привычек
- `task_dependencies` — зависимости задач
- `weekly_reviews` — еженедельные обзоры (со стриками)
- `habit_routines` / `habit_routine_members` — рутины
- `goal_map_elements` — элементы тактической карты
- `goal_node_attachments` — вложения
- `planning_task_assignees` / `sub_goal_assignees` — исполнители
- `meditation_presets` / `meditation_sessions` — медитации
- `user_inventory` — инвентарь кастомизации
- `leaderboard_winners` — победители авангарда
- `avatar_frames`, `profile_backgrounds`, `stat_styles`, `profile_patterns` — элементы кастомизации
- `friends` / `friend_requests` — социальная система
- `notifications` — уведомления

### Edge Functions:
- `ai-decompose` — AI-декомпозиция задач
- `daily-winner` — определение победителя авангарда
- `cleanup-attachment-storage` — очистка Storage
- `telegram-auth` — OAuth2-адаптер для Telegram Login Widget (Custom OAuth Provider `custom:telegram`)

### Ключевые RPC-функции:
- `increment_xp(p_user_id, p_amount)` — начисление XP
- `add_design_points(p_amount)` — начисление DP
- `log_weekly_review(...)` — идемпотентное логирование обзора (+ обновление стрика)

### Storage buckets:
- `avatars` — аватары пользователей
- `goal-attachments` — вложения к целям

### RLS:
- Все таблицы защищены RLS-политиками для изоляции данных пользователей
- Известная проблема: рекурсия RLS в совместных целях (исправлена миграцией `20260625000001_fix_collab_rls_recursion.sql`)

---

## 6. Архитектура Offline-first

### Принцип работы:
1. Все данные пишутся в локальную Drift-БД (мгновенный отклик UI)
2. Параллельно операция ставится в очередь `PendingSyncOps`
3. `SyncService.syncAll()` вызывается:
   - При запуске приложения (`MainNavigationShell._setupSync()`)
   - При восстановлении соединения (слушатель `connectivityProvider`)
4. Операции выполняются последовательно, при ошибке — инкремент `attempts`
5. После 10 попыток операция удаляется (`purgeDeadSyncOps`)
6. RLS-ошибки (42501) и рекурсии (42P17) удаляются сразу как невосстановимые
7. XP/DP накапливаются в `pendingXp`/`pendingDp`, пушатся одним батчем через RPC

### Типы sync-операций (более 40):
`insert_habit`, `update_habit`, `delete_habit`, `insert_habit_log`, `update_habit_log`, `update_habit_log_value`, `delete_habit_log`, `insert_routine`, `update_routine_meta`, `sync_routine_members`, `delete_routine`, `insert_goal`, `delete_goal`, `update_goal_status`, `insert_sub_goal`, `delete_sub_goal`, `complete_sub_goal`, `insert_task`, `toggle_task`, `delete_task`, `insert_milestone`, `complete_milestone`, `delete_milestone`, `insert_goal_snapshot`, `insert_mission_template`, `insert_weekly_review`, `insert_dependency`, `delete_dependency`, `insert_habit_link`, `delete_habit_link`, `move_task`, `update_goal_progress`, `update_goal_settings`, `award_mission_medal`, `reorder_sub_goal`, `reorder_task`, `update_goal_pin`, `upload_attachment`, `delete_attachment`, `upsert_map_element`, `delete_map_element`, `assign_node`, `unassign_node`

---

## 7. Геймификация

- **XP-система:** 1 уровень = 1000 XP. Прогрессия от "Recruit" до "Commander"
- **Design Points (DP):** Валюта для магазина кастомизации
- **Награды:**
  - +50 XP за выполнение привычки
  - +XP/DP за фокус-сессии и дыхательные практики
  - Медали миссий (Bronze/Silver/Gold) + XP-бонусы
  - Dynamic Streak Bonus для целей (x1.5 за 7 дней, x2.0 за 30 дней)
- **Авангард Суток:** Ежедневный лидерборд (Edge Function `daily-winner`)
- **Анти-чит:** `planningSources/xp-anti-farming.md`

---

## 8. Тематические модули (состояние реализации)

### Planning Module (Интеллектуальное планирование) — реализован
- Tactical Map: интерактивный граф целей с drag-and-drop
- Иерархия: Миссия → Подцели → Задачи → Вехи
- Fog of War: скрытие будущих этапов
- Mission Medals: автоматическая выдача Bronze/Silver/Gold
- Strategic Advice: советы при стагнации
- Task Dependencies, Recurring Tasks, Milestone Metrics
- Goal Progress Snapshots (один в день на цель)
- Mission Templates (системные и пользовательские)
- Weekly Reviews со стриками
- **Collaboration:** совместные цели, назначение исполнителей, realtime-карта

### Habit Tracker (Матрица привычек) — реализован
- Полный CRUD + архивация + закрепление
- Типы: binary / count / duration
- Расписания: daily / weekdays / weekly:N / interval:N
- Рутины: morning / evening / stack (с anchor cue)
- Streak Resilience: rest-дни не ломают стрик
- Полярность: build (формировать) / avoid (ломать вредную)
- Life Areas: health / mind / productivity / relationships / finance / spirit
- Habit Journaling: заметки + эмодзи к логам
- Напоминания (reminderTime)
- Templates Library
- +50 XP за выполнение

### Meditation & Breathing — реализован
- **Дыхание:** Вима Хоф, визуализатор сферы (GLSL shader `breathing_sphere.frag`)
- Аудио-синхронизация: `PlaybackRate = AssetDuration / TargetDuration`
- **Медитация:** пресеты (system/user), бинауральные ритмы, аффирмации
- Состояния до/после (stateBefore/After)
- Конструктор пресетов

### Operations Control (Главный штаб) — реализован
- Дашборд: XP, уровень, статус оператора
- Branch Navigation: быстрый доступ к модулям
- Bootcamp Activity (кросс-модульные дневные цели)

### Social & Gamification — реализован
- Shop System: визуальные улучшения за DP
- Operative Dossier: публичные/приватные профили
- Daily Leaderboard: «Авангард Суток»
- Friends: список друзей, поиск пользователей
- Goal Collaboration: совместные цели, назначение исполнителей
- Customization: avatar frames, profile backgrounds, stat styles, profile patterns

---

## 9. Навигация приложения

```
SieApp
  └─ SieSplashScreen → onComplete
     └─ _authGate()
        ├─ AuthScreen (если не авторизован)
        └─ MainNavigationShell (если авторизован)
           ├─ [0] ProfileScreen (Hub)      — личный профиль
           ├─ [1] OperationsControlScreen  — главный дашборд (по умолчанию)
           ├─ [2] GarageScreen             — магазин
           └─ [3] LeaderboardScreen        — зал славы
              ↓ (push-навигация)
              ├─ PlanningScreen → MissionDetail → TacticalMap
              ├─ HabitTracker → HabitDetail
              ├─ FocusProtocol
              ├─ BreathingExercise
              ├─ MeditationHub → MeditationSession
              ├─ UserSearch → PublicProfile
              ├─ FriendsList
              └─ ...
```

- **Push-навигация** через `Navigator.push` (MaterialPageRoute)
- **Cupertino transitions** на всех платформах (swipe-back на Android)
- **Notification taps** роутятся через `rootNavigatorKey` → PlanningScreen или HabitTracker

---

## 10. Темы и дизайн

**SieTheme** (`packages/sie_core/lib/src/theme/sie_theme.dart`):
- `classicDark` — anthracite тёмная, gold-sand акценты (#C8A84B)
- `classicLight` — светлая, gold-sand primary + seafoam-teal secondary (#5AADA0)

**Компоненты темы:** `SieColors`, `SieHaptics` (тактильная отдача), `SieMotion` (длительность анимаций)

**Ассеты:**
- Аудио: `ambient.mp3`, `inhale.mp3`, `exhale.mp3`, `notification_end.mp3`
- Шейдер: `breathing_sphere.frag` (воздушная сфера для дыхания)
- Иконки: `app_icon.png`, `orb_splash.png` (несколько разрешений r32-r38)

---

## 11. Git Flow и релизный процесс

### Ветвление:
- `main` — стабильная ветка (релизы)
- `dev` — разработка (мержится в main через PR)
- `feature/*` — новые фичи
- `bugfix/*` — багфиксы
- `design` — дизайн-изменения
- `gh-pages` — веб-деплой (автоматически из `deploy.sh`)

### Команда «Делай релиз»:
Когда пользователь говорит **«Делай релиз»**, выполнить:
1. Закоммитить и запушить изменения в `dev`
2. `flutter analyze` в `apps/central_hub` — исправить ошибки
3. Прочитать версию из `pubspec.yaml`, увеличить patch+build
4. Собрать APK: `flutter build apk --release` (с правильным PATH)
5. Переименовать в `SiE-Hub-vX.Y.Z.apk`, скопировать в корень
6. Создать релиз на GitHub (тег `vX.Y.Z`, описание на русском, прикрепить APK)

### Сборка APK (команда):
```bash
export PATH="/opt/flutter/bin:/opt/android/cmdline-tools/latest/bin:/opt/android/platform-tools:$PATH"
export ANDROID_HOME=/opt/android
git config --global --add safe.directory /opt/flutter
cd apps/central_hub
flutter build apk --release
```

### Веб-деплой:
```bash
./deploy.sh  # flutter build web → gh-pages branch → force push
```

### iOS (Codemagic):
- `codemagic.yaml` → iOS unsigned IPA build (mac_mini_m1, stable Flutter)

---

## 12. Режим планирования

**Активация:** фраза **«Переходим в режим планирования»**

**Правила:**
1. Читать можно любые файлы
2. Писать/изменять можно ТОЛЬКО `.md` файлы в `planningSources/`
3. Запрещено изменять код (`.dart`, `.yaml`, `.json`, `.sql`)
4. Каждый план — отдельный файл `planningSources/feature-*.md`

**Структура плана:** Описание → Сценарий → Логика → Модули → Схема данных → Вопросы

**Выход:** фраза «выходим из режима планирования» / «начинаем реализацию»

---

## 13. Режим исследования

**Активация:** фраза **«Переходим в режим исследования»**

Глубокий анализ кодовой базы, архитектурное проектирование, только `.md` файлы в `planningSources/`, код только в режиме чтения.

---

## 14. Кодогенерация

При изменении Drift-схемы (`app_database.dart`):
```bash
cd packages/sie_core
dart run build_runner build -d
```
Генерируются `*.g.dart` файлы (в `.gitignore`).

---

## 15. Известные баги и техдолг

**Файл:** `planningSources/FOUNDBUGS.md`

Все критические баги на данный момент ИСПРАВЛЕНЫ:
- ✅ 30-Day Streak Cap → расширено до 366 дней
- ✅ Duplicate Log Risk → `_inProgress` + UNIQUE constraint
- ✅ Volatile Focus Session State → персист в SharedPreferences
- ✅ Incomplete Logout Flow → `ref.invalidate()` + авто-редирект

---

## 16. Roadmap до v1.0 (31 июля 2026)

**Файл:** `planningSources/PLANNING.md`

1. **Стабилизация и Фундамент** — утечки памяти, анти-чит, синхронизация
2. **Углубление инструментов** — количественные привычки, пресеты фокуса, белый шум
3. **Редизайн Hub** — радар баланса, визуальное ядро, схлопывающиеся карточки
4. **Монетизация** — подписка Elite Tier, эксклюзивная кастомизация, Pro-аудио
5. **Удержание** — push-уведомления, виджеты (Android & iOS)
6. **Геймификация** — Streak Freeze, Tech Tree, Сезоны

---

## 17. Важные принципы разработки

- **Offline-first:** локальная БД — источник истины для UI, синхронизация фоновая
- **RLS:** все таблицы Supabase защищены политиками изоляции данных
- **Сухой технический код:** высокая модульность, без лишней логики в UI
- **Переиспользуемые виджеты:** визуальные эффекты (пульсация, градиенты) в `sie_core/widgets/`
- **Коммиты на русском** для релизных описаний
- **Не коммитить** без явного запроса пользователя
- **Не добавлять комментарии** в код без явной просьбы
- Версия БД увеличивается при каждом изменении схемы (`schemaVersion` в `app_database.dart`)