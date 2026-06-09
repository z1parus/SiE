# Структура Базы Данных (Supabase Schema) — Planning Module

## 1. Таблицы и Поля

### А. Таблица `goals` (Глобальные Цели)
Хранит основные данные о миссиях пользователя.
*   `id`: `uuid` (Primary Key)
*   `user_id`: `uuid` (Foreign Key -> profiles.id)
*   `name`: `text` (Название цели)
*   `description`: `text` (Описание)
*   `deadline`: `timestamp with time zone` (Финальный дедлайн)
*   `priority`: `int` (1 - Low, 2 - Medium, 3 - High, 4 - Critical)
*   `status`: `text` (active, completed, archived, frozen)
*   `color_hex`: `text` (Цветовой код для UI)
*   `settings`: `jsonb` (Индивидуальные настройки: туман войны, уведомления и т.д.)
*   `created_at`: `timestamp with time zone`
*   `updated_at`: `timestamp with time zone`

### Б. Таблица `sub_goals` (Под-цели)
Логические группы задач внутри Глобальной Цели.
*   `id`: `uuid` (Primary Key)
*   `goal_id`: `uuid` (Foreign Key -> goals.id, ON DELETE CASCADE)
*   `parent_sub_goal_id`: `uuid` (Self-reference, для вложенности)
*   `name`: `text`
*   `order_index`: `int` (Для сортировки в списке)
*   `is_completed`: `boolean`
*   `created_at`: `timestamp with time zone`

### В. Таблица `milestones` (Контрольные Точки)
Ключевые вехи миссии.
*   `id`: `uuid` (Primary Key)
*   `goal_id`: `uuid` (Foreign Key -> goals.id)
*   `name`: `text`
*   `target_date`: `timestamp with time zone`
*   `is_reached`: `boolean`
*   `reached_at`: `timestamp with time zone`

### Г. Таблица `planning_tasks` (Задачи)
Конкретные атомарные действия.
*   `id`: `uuid` (Primary Key)
*   `user_id`: `uuid` (Foreign Key -> profiles.id)
*   `sub_goal_id`: `uuid` (Foreign Key -> sub_goals.id, NULL если задача отдельная)
*   `name`: `text`
*   `weight`: `int` (1, 3, 5 - согласно PlanningModuleLogic.md)
*   `due_date`: `timestamp with time zone`
*   `is_completed`: `boolean`
*   `completed_at`: `timestamp with time zone`

### Д. Таблица `goal_habit_links` (Связь с Привычками)
Связующее звено между миссиями и ежедневной рутиной.
*   `id`: `uuid` (Primary Key)
*   `goal_id`: `uuid` (Foreign Key -> goals.id)
*   `habit_id`: `uuid` (Foreign Key -> habits.id)
*   `boost_value`: `float` (Значение бонуса к прогрессу за выполнение)

---

## 2. Связи (Relationships)

1.  **One-to-Many:** `goals` -> `sub_goals` (Одна цель — много этапов).
2.  **One-to-Many:** `sub_goals` -> `planning_tasks` (Один этап — много задач).
3.  **Many-to-Many (через таблицу):** `goals` <-> `habits` (Цель может подпитываться разными привычками, и одна привычка может влиять на разные цели).

---

## 3. Политики Безопасности (RLS)

*   **SELECT:** `auth.uid() = user_id` (Пользователь видит только свои цели).
*   **INSERT:** `auth.uid() = user_id` (Пользователь может создавать цели только для себя).
*   **UPDATE/DELETE:** `auth.uid() = user_id` (Полный доступ к своим данным).

---

## 4. Триггеры и Автоматизация (Database Functions)

1.  **Auto-Progress:** Триггер на изменение `is_completed` в `planning_tasks`. При изменении пересчитывает прогресс связанной `sub_goal` и `goal`.
2.  **Habit-to-Goal Feed:** Функция, которая при записи лога в `habit_logs` проверяет наличие связи в `goal_habit_links` и обновляет прогресс миссии.
3.  **XP Reward:** При смене статуса цели на `completed` автоматически начислять XP в таблицу профиля.
