# Identified Bugs & Technical Debt (FOUNDBUGS.md)

This document tracks "invisible" bugs, potential race conditions, and technical debt identified during codebase analysis.

## 1. State & Race Conditions
- **Partial XP Loss:** In `BreathingExerciseScreen.dart`, `_awardPartialXpIfEligible` is called on back-navigation but not awaited. Slow network requests to Supabase may be cancelled before completion, causing lost progress.
- **Midnight Boundary (Local vs. Server Time):** The Habit Tracker uses local `DateTime.now()`. This can cause synchronization issues and broken streaks if the user's local time differs significantly from the Supabase server's UTC time or if they log a habit right at midnight.

## 2. Audio Subsystem
- **Resource Leaks:** Potential for `Timer.periodic` instances in `AudioService` (within `sie_core`) to persist if not explicitly cancelled during rapid screen transitions, leading to overlapping audio or background battery drain.
- **Web Audio Context:** Possible "silent starts" on Web if the `AudioContext` isn't resumed by a user gesture before the first breathing sound is triggered.

## 3. Visual Engine (Liquid Glass)
- **GPU Performance Bottlenecks:** Heavy shaders in `LiquidGlassWidgets` may cause significant FPS drops or input lag on budget Android devices. The system lacks a fallback notification or automatic performance degradation for the user.
- **Hardcoded Configuration:** Supabase URL and Anon Key are hardcoded in `main.dart`, complicating environment switching and CI/CD pipelines.

## 4. Error Handling & UX
- **Misleading Error Messages:** Most screens (`HabitTracker`, `Leaderboard`) default to showing a "No Connection" message for *any* error (including 403 Forbidden or 500 Internal Server Error), hiding actual backend or permission issues.
- **Silent RLS Failures:** Potential for Supabase Row Level Security (RLS) policies to silently reject inserts/updates. If the client-side cache updates but the server rejects the change, data may "disappear" upon the next hard refresh without notifying the user.

## 5. Persistence
- **Drift/Local DB Sync:** Ensure that the local `drift` database in `sie_core` stays in perfect sync with Supabase during offline/online transitions to prevent duplicate habit logs or state divergence.

## 6. Breathing Tool Specific (Audit Results)
- **Zombie Timers:** `_runNextCycle`, `_endRetention`, and `_scheduleNextHeartbeat` create timers that are not tracked in `_cancelTimers()`. These persist after `dispose()` or `_restartSession()`, causing memory leaks and background `setState()` calls.
- **Heartbeat Logic Flaw:** Recursive `_scheduleNextHeartbeat` calls cannot be cancelled. If settings change during a session, the heartbeat might never trigger or trigger multiple times.
- **Incomplete Reset:** `_restartSession` fails to stop `_circleCtrl` and `_pulseCtrl` animations, leading to visual glitches during the countdown phase.
- **XP Awarding Race Condition:** `_awardPartialXpIfEligible` is not awaited in `_onBack()`. The navigation happens before the network request finishes, often resulting in zero XP gained for interrupted sessions.
- **AV Desync:** Audio cues start via native Soundpool independently of Flutter's animation frame. Under heavy GPU load (Liquid Glass), the visual circle may lag behind the audio by several frames.
- **Division by Zero Risk:** Lack of validation for `inhaleSecs` and `exhaleSecs` in settings. Values of 0 could break animation controllers or timer calculations.

## 7. Habit Tracker Specific (Audit Results)
- **Stale Local Cache:** Local Drift DB is updated via `upsert` but never pruned. Habits deleted on other devices stay in local storage indefinitely, causing "ghost" habits in offline mode.
- **Client-Side Streak Forgery:** Streak calculation depends on client-provided timestamps and local logic. Users can manipulate system time to "repair" broken streaks and gain unearned XP.
- **Brittle Custom Swipe:** The manual `_dragOffset` implementation lacks an "Undo" mechanism and doesn't gracefully handle network failures during deletion. The UI removes the card before the server confirms deletion.
- **Missing Offline Fallback UI:** Despite having a local DB, the screen displays a "No Connection" error if Supabase is unreachable, instead of seamlessly switching to local data.
- **30-Day Streak Cap:** Habit logs are only fetched for the last 30 days. Any streak longer than 30 days will be calculated incorrectly once the oldest logs fall outside the fetching window.
- **Duplicate Log Risk:** `toggleHabit` uses local `DateTime.now()`. If called multiple times quickly or during sync retries, it may create duplicate log entries for the same day in Supabase.

## 8. Focus Protocol Specific (Audit Results)
- **Volatile Session State:** Active session data (time remaining, start time) lives only in memory. If the OS kills the app process during a 25-minute focus block, all progress is lost upon restart. No persistent "active_session" record exists.
- **Instant XP Exploitation:** XP is awarded based on client-side timer completion. Users can skip focus time by manually advancing the system clock or triggering `handleForeground` with manipulated data.
- **Asynchronous Phase Lag:** `_onPhaseComplete` awaits a network request to Supabase *before* updating the UI to the next phase. If the connection is slow, the timer stays stuck at `00:00` for several seconds after the transition chime.
- **Audio Overlap Risk:** `updateSettings` and `start()` manage `AudioService` without checking current playback state. Rapidly toggling settings or pausing/resuming can lead to multiple ambient tracks playing simultaneously.
- **Z-Index Clipping:** The `OnboardingOverlay` is placed in a `Stack` that could potentially be clipped by parent `GlassPage` layers if the hierarchy changes, making the "Accept" button unreachable.

## 9. Operations Control Specific (Audit Results)
- **Navigation Stack Pollution:** `_FloatingNavBar` uses `Navigator.push` without checking for existing routes. Rapid tapping on nav items creates multiple instances of the same screen, leading to memory leaks and broken back-button behavior.
- **Welcome Modal Race Condition:** `ref.listen` may trigger `showDialog` before the widget tree is ready, causing Navigator errors. Also, the local `_welcomeShown` flag resets on screen re-entry, potentially re-triggering the modal.
- **Hardcoded Slug Dependency:** Branch navigation is hardcoded to specific string slugs (e.g., `habit_archive`). Any change in the Supabase `branches` table will silently break the main app navigation.
- **Carousel Repaint Storm:** The `_BranchCarousel` and its animated previews (`_BreathSpherePreview`) lack proper `RepaintBoundary` isolation, causing the entire dashboard to repaint on every animation frame (60/120fps), impacting battery life.
- **Incomplete Logout Flow:** `signOut` in the header does not clear Riverpod state or force-redirect to `AuthScreen`, leaving the user in a "zombie" state with permission errors until a manual restart.
- **Magic Number Padding:** The bottom padding of `148` is hardcoded to clear the floating nav bar but doesn't account for varying device aspect ratios or system safe areas, potentially obscuring content or leaving gaps.
