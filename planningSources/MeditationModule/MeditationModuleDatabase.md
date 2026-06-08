# Структура Базы Данных (Supabase Schema) — Meditation Module

## 1. Таблицы и Поля

### А. Таблица `meditation_presets` (Пользовательские Пресеты)
Хранит настройки сессий для быстрого запуска.
*   `id`: `uuid` (Primary Key)
*   `user_id`: `uuid` (Foreign Key -> profiles.id)
*   `name`: `text` (Название пресета)
*   `description`: `text` (Краткое описание)
*   `is_system`: `boolean` (True для предустановленных пресетов от разработчиков)
*   
*   **Конфигурация цепочки:**
    *   `has_breathing`: `boolean` (Включена ли дыхательная практика)
    *   `breathing_pattern_id`: `text` (Ссылка на тип дыхания: box, 4-7-8 и т.д.)
    *   `meditation_type`: `text` (unguided, affirmations)
    *   `total_duration_min`: `int` (Общая длительность)
    *   
*   **Конфигурация Аудио:**
    *   `base_music_id`: `text` (ID фонового трека)
    *   `ambient_fx_id`: `text` (ID звуков природы)
    *   `base_volume`: `float` (Громкость музыки 0.0-1.0)
    *   `ambient_volume`: `float` (Громкость эмбиента)
    *   `voice_volume`: `float` (Громкость аффирмаций)
    
*   `created_at`: `timestamp with time zone`

### Б. Таблица `meditation_logs` (Журнал Сессий)
Запись каждой завершенной медитации для аналитики.
*   `id`: `uuid` (Primary Key)
*   `user_id`: `uuid` (Foreign Key -> profiles.id)
*   `preset_id`: `uuid` (Foreign Key -> meditation_presets.id, NULL если запуск был разовым)
*   `duration_seconds`: `int` (Фактическое время в медитации)
*   `state_before`: `int` (Оценка состояния 1-5 до сессии)
*   `state_after`: `int` (Оценка состояния 1-5 после сессии)
*   `completed_at`: `timestamp with time zone`

### В. Таблица `affirmation_packs` (Наборы Аффирмаций)
*   `id`: `uuid` (Primary Key)
*   `name`: `text` (Название: "Уверенность", "Спокойствие")
*   `phrases`: `text[]` (Массив строк с аффирмациями)
*   `is_custom`: `boolean` (Свой набор пользователя или системный)
*   `user_id`: `uuid` (NULL для системных)

---

## 2. Связи (Relationships)

1.  **One-to-Many:** `profiles` -> `meditation_presets` (У пользователя много своих пресетов).
2.  **One-to-Many:** `profiles` -> `meditation_logs` (История медитаций пользователя).
3.  **Many-to-One:** `meditation_logs` -> `meditation_presets` (Лог ссылается на пресет для аналитики эффективности конкретных настроек).

---

## 3. Политики Безопасности (RLS)

*   **meditation_presets:**
    *   SELECT: `user_id = auth.uid() OR is_system = true` (Видеть свои и системные).
    *   INSERT/UPDATE/DELETE: `user_id = auth.uid()` (Управлять только своими).
*   **meditation_logs:**
    *   SELECT/INSERT: `user_id = auth.uid()` (Полная приватность истории).
*   **affirmation_packs:**
    *   SELECT: `user_id = auth.uid() OR is_custom = false` (Видеть свои и общие).

---

## 4. Автоматизация и Триггеры

1.  **Clarity XP Trigger:** При добавлении записи в `meditation_logs` автоматически начислять XP в таблицу `profiles`.
    *   Формула: `XP = (duration_seconds / 60) * Multiplier`.
2.  **Zen Streak Counter:** Функция, которая при сохранении лога проверяет дату последней медитации и обновляет `zen_streak` в профиле (или отдельной таблице статистики).
3.  **Daily Analytics:** Materialized view для быстрого подсчета времени осознанности за неделю/месяц для виджетов на главном экране.
