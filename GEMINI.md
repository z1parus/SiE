# Project Instructions (GEMINI.md)

## Assistant Role & Responsibilities
- **Primary Focus:** Project planning, codebase analysis, and architectural guidance.
- **Git & GitHub:** Assist with version control tasks, commit message drafting, and PR preparation.
- **Workflow:** Act as a senior peer programmer, providing high-signal technical rationale and maintaining engineering standards.

## Project Architecture & Structure

### 1. Workspace Overview
- **Type:** Multi-package Flutter/Dart project (Monorepo-lite).
- **Core Stack:** Flutter (SDK ^3.11.5), Riverpod (State Management), Supabase (Backend/Auth), Liquid Glass (Visual Engine).

### 2. Modules & Packages
- **`apps/central_hub` (Main App):**
  - The primary entry point and user interface.
  - **Dependencies:** `flutter_riverpod`, `supabase_flutter`, `fl_chart`, `liquid_glass_widgets`, `sie_core` (local).
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
- **Theming:** `SieTheme` with custom modes (e.g., `cosmicLiquidGlass`).
- **Data Flow:** Repository/Service pattern via `sie_core`.
- **Navigation:** Shell-based navigation for a persistent UI experience.
