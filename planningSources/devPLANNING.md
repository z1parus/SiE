# Технический план реализации (devPLANNING.md)

В данном документе описаны архитектурные и технические решения для внедрения идей из `PLANNING.md` в существующий стек (Flutter, Riverpod, Drift, Supabase, Liquid Glass).

---

## 🛠 Этап 2: Углубление функционала инструментов

### 1. Трекер привычек (Anti-habits, Сцепки, Типы)
- **БД (Supabase & Drift):** 
  - Изменить таблицу `habits`: добавить поле `habit_type` (enum: `positive`, `negative`, `quantitative`) и `target_value` (int, для количественных).
  - Создать новую таблицу `habit_chains` (id, user_id, name) и `habit_chain_items` (chain_id, habit_id, step_order).
- **Логика (Riverpod):**
  - Обновить `HabitsNotifier`: при отметке `negative` привычки вызывать RPC-функцию Supabase для списания XP (штраф).
  - Создать `HabitChainNotifier` для управления состоянием пошагового выполнения цепочки привычек (сохранение прогресса в памяти до завершения всей цепочки).

### 2. Фокусировка (Strict Mode, Тегирование)
- **БД:** Добавить колонку `tag_id` в таблицу `focus_sessions` и создать таблицу `focus_tags` (id, user_id, name, color).
- **Strict Mode (Riverpod):** 
  - В `FocusTimerNotifier` добавить слушатель `AppLifecycleState`. Если приложение переходит в `paused` во время фазы `work`, и включен `strict_mode`, немедленно прерывать таймер, вызывать `audio.stopAll()` и отправлять на сервер статус `failed`.
- **Пресеты:** Создать локальную модель `FocusPreset` (Pomodoro 25/5, Deep Work 90/15) и сохранять выбранный пресет в `SharedPreferences` или `Drift`.

---

## 📊 Этап 3: Редизайн Hub (Досье Оперативника)

### 1. Радар баланса
- **UI:** Использовать пакет `fl_chart` (уже есть в зависимостях) для виджета `RadarChart`.
- **Data:** Написать SQL View или RPC в Supabase `get_user_balance_stats(user_id)`, который агрегирует количество сессий Фокуса, Дыхания и Привычек за последние 7 дней, возвращая нормализованные значения (0.0 - 1.0).
- **State:** Создать `BalanceStatsProvider` (FutureProvider), запрашивающий эти данные при загрузке профиля.

### 2. Визуальное ядро (Core)
- **UI:** Интегрировать `LiquidGlassWidgets` (или кастомный FragmentShader). Передавать уровень пользователя (`userProfile.level`) в качестве `uniform` переменной в шейдер для изменения амплитуды пульсации, цвета и количества частиц.
- **Оптимизация:** Обернуть виджет Ядра в `RepaintBoundary`, чтобы его 60fps анимация не перерисовывала весь скролл-список `ProfileScreen`.

---

## 💳 Этап 4: Монетизация и Платный контент

### 1. Архитектура подписок
- **Пакет:** Интегрировать `purchases_flutter` (RevenueCat) или использовать прямую интеграцию API онлайн-кассы (ЮKassa/Stripe) через Supabase Edge Functions (Webhooks).
- **БД:** Добавить поле `subscription_tier` (enum: `free`, `elite`) в таблицу `profiles`. Обновлять его через Webhook от платежного шлюза.
- **RLS (Row Level Security):** Настроить политики Supabase так, чтобы таблицы премиум-контента (курсы, премиум-аудио) были доступны для чтения только пользователям с `subscription_tier = 'elite'`.

### 2. Защита на клиенте
- В `sie_core` создать `SubscriptionProvider`. Для премиальных шейдеров делать проверку: `if (ref.watch(subscriptionProvider).isElite) ...`.

---

## 🔔 Этап 5: Удержание (Push и Виджеты)

### 1. Push-уведомления
- **Пакет:** Интегрировать `firebase_messaging` и `flutter_local_notifications` (для локальных напоминаний).
- **Бэкенд:** 
  - Настроить Supabase Edge Function `send-reminders`.
  - Использовать расширение `pg_cron` в PostgreSQL для ежедневного запуска функции, которая проверяет `habit_logs` и отправляет Push пользователям, не закрывшим привычки к 20:00.
  - Сохранять FCM-токены девайсов в новую таблицу `user_devices`.

### 2. Виджеты рабочего стола (iOS/Android)
- **Пакет:** Интегрировать `home_widget`.
- **Обмен данными:** Настроить App Groups (iOS) и SharedPreferences (Android), чтобы Flutter-приложение могло записывать данные (текущий XP, список привычек) в нативный кэш.
- **Нативная часть:** Написать базовые виджеты на Swift (WidgetKit) и Kotlin (Glance), которые читают этот кэш и отображают кольцо прогресса или кнопку "Старт фокуса" (через Deep Link).

---

## 🎮 Этап 6: Геймификация (Мета-игра)

### 1. Магазин и Заморозка
- **БД:** 
  - Таблица `shop_items` (id, type: 'streak_freeze', price_dp).
  - В `profiles` добавить колонку `inventory` (jsonb) или создать таблицу `user_inventory`.
- **Логика:** При пропуске дня в `HabitsNotifier` проверять наличие 'streak_freeze' в инвентаре. Если есть — не обнулять стрик, списывать предмет и визуально отображать иконку ❄️ (льдинки) в календаре.

### 2. Древо талантов (Tech Tree)
- **БД:** Таблица `user_skills` (user_id, skill_id, level).
- **State:** `SkillsProvider`. 
- **Модификаторы:** При расчете XP за Фокус (в `FocusTimerNotifier._saveWorkSession`) применять множитель из навыка: `final xp = baseXp * (1.0 + (focusSkillLevel * 0.05))`.

### 3. Сезоны (Cycles)
- **БД:** Таблица `seasons` (id, start_date, end_date). Таблица `leaderboard_history` (season_id, user_id, final_rank, total_xp).
- **Бэкенд:** Триггер `pg_cron` в 00:00 первого числа месяца переносит топ-100 из текущего расчета в `leaderboard_history`, обнуляет счетчик "сезонного XP" и выдает уникальные бейджи (запись в `user_achievements`).
