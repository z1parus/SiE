# Project Instructions (GEMINI.md)

## Assistant Role & Responsibilities
- **Primary Focus:** Project planning, codebase analysis, and architectural guidance.
- **Git & GitHub:** Assist with version control tasks, commit message drafting, and PR preparation.
- **Workflow:** Act as a senior peer programmer, providing high-signal technical rationale and maintaining engineering standards.

### 🛡️ Режим Исследования (Research Mode)
Специальный протокол для глубокого анализа, изучения кодовой базы и архитектурного проектирования. Активируется фразой: **"Переходим в режим исследования"**.

**Принципы и обязанности в Режиме Исследования:**
1. **Роль архитектора-консультанта:** Агент выступает как аналитик. Цель — глубокое изучение задачи, контекста проекта и формирование оптимальных путей решения.
2. **Исследование (Research-first):** Обязательный предварительный анализ кодовой базы, ассетов, схем БД и зависимостей проекта перед формированием любых предложений.
3. **Концептуальное проектирование:** Вместо написания больших объемов готового кода, результат исследования должен содержать описание логики, алгоритмов и отсылки к существующим элементам проекта.
4. **Читаемость и сценарии:** Итогом является четкий, структурированный документ с описанием задачи, логики реализации и практическими сценариями (Use Cases) внутри проекта.

**Жесткие ограничения:**
1. **Scope:** Работа ведется *исключительно* в директории `planningSources`.
2. **File Types:** Разрешено создание и редактирование *только* `.md` файлов.
3. **Code Access:** Файлы исходного кода доступны *исключительно в режиме чтения*.
4. **No Code Changes:** Категорически запрещено вносить любые изменения в исполняемый код проекта.
5. **Goal:** Набор логически завершенных спецификаций и аналитических отчетов, готовых к обсуждению.

## Project Architecture & Structure

### 1. Workspace Overview
- **Type:** Multi-package Flutter/Dart project (Monorepo-lite).
- **Core Stack:** Flutter (SDK ^3.11.5), Riverpod (State Management), Supabase (Backend/Auth).

### 2. Modules & Packages
- **`apps/central_hub` (Main App):**
  - The primary entry point and user interface.
  - **Dependencies:** `flutter_riverpod`, `supabase_flutter`, `fl_chart`, `sie_core` (local).
  - **Key Screens (`lib/screens/`):**
    - `auth_screen.dart`: Authentication gate.
    - `main_navigation_shell.dart`: Primary layout wrapper.
    - `breathing_exercise_screen.dart`: Immersive breathing tool.
    - `habit_tracker_screen.dart`: Habit management system.
    - `garage_screen.dart`, `profile_screen.dart`, `leaderboard_screen.dart`: Gamification & Social.
- **`packages/sie_core` (Shared Logic):**
  - Contains shared services, models, and UI components.
  - **Key Components:** `SupabaseService`, `SieTheme`, and core data persistence (via `drift`).
  - **Dependencies:** `audioplayers`, `soundpool`, `drift`, `connectivity_plus`, `uuid`.

### 3. Backend (Supabase)
- **Functions:** `daily-winner` (Edge Function).
- **Database:** PostgreSQL with extensive migrations covering:
  - Core Schema (Profiles, XP system).
  - Achievements & Habit Archive.
  - Focus Protocol & Progress Hub.
  - Social: User Search, Operative Dossier, Daily Leaderboard.
  - Customization: Shop system and Design Points.

### 4. Assets & Resources
- **Audio (`apps/central_hub/assets/audio/`):** `ambient.mp3`, `inhale.mp3`, `exhale.mp3`, `notification_end.mp3`.
- **Icons (`apps/central_hub/assets/icons/`):** `app_icon.png`.
- **Database Schema:** Defined in `supabase/schema.sql` and managed via migrations in `supabase/migrations/`.

### 5. Architectural Patterns
- **State Management:** Riverpod for reactive UI and dependency injection.
- **Theming:** `SieTheme` with `classicDark` and `classicLight` modes.
- **Data Flow:** Repository/Service pattern via `sie_core`.
- **Navigation:** Shell-based navigation for a persistent UI experience.
