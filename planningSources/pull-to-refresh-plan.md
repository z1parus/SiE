# Pull-to-Refresh (RefreshIndicator) Implementation Plan

## Objective
Add `RefreshIndicator` with pull-to-refresh functionality across all relevant screens to allow users to manually update state and synchronize data with Supabase.

## Strategy
1.  **Widget Wrapping:** Wrap the primary scrollable view (e.g., `SingleChildScrollView`, `ListView`, `CustomScrollView`, `ReorderableListView`) on each target screen with a `RefreshIndicator`.
2.  **Scroll Physics:** Ensure the wrapped scrollable view uses `physics: AlwaysScrollableScrollPhysics()` so that the refresh action can be triggered even if the content doesn't fill the entire screen height.
3.  **State Invalidation:** Within the `onRefresh` callback, use `ref.invalidate(...)` on the relevant asynchronous Riverpod providers, followed by `await ref.read(...future)` to wait for the data to fetch before hiding the refresh spinner.
4.  **Styling:** Use standard app styling for the indicator:
    *   `color: sc.accent`
    *   `backgroundColor: sc.isLightMode ? Colors.white : const Color(0xFF0D1B2A)` (consistent with existing implementations).

## Target Screens & Implementation Details

### 1. Habit Tracker Screen (`apps/central_hub/lib/screens/habit_tracker_screen.dart`)
*   **Target View:** The main `ListView` or scrollable list displaying habits.
*   **Providers to Invalidate:**
    *   `habitsProvider`
    *   `habitRoutinesProvider`
    *   `archivedHabitsProvider`
    *   `userProfileProvider`

### 2. Planning / Tactical Map (`apps/central_hub/lib/screens/planning_screen.dart`)
*   **Target View:** The main `SingleChildScrollView` or `CustomScrollView` representing the map/list.
*   **Providers to Invalidate:**
    *   `planningProvider`

### 3. Operations Control Screen (`apps/central_hub/lib/screens/operations_control_screen.dart`)
*   **Target View:** The main scrollable view holding the daily briefing, branches, notifications, etc.
*   **Providers to Invalidate:**
    *   `branchesProvider`
    *   `planningProvider`
    *   `habitsProvider`
    *   `userProfileProvider`
    *   `notificationsProvider`

### 4. Mission Detail Screen (`apps/central_hub/lib/screens/mission_detail_screen.dart`)
*   **Target View:** The main `SingleChildScrollView` containing mission parameters, objectives, and linked habits.
*   **Providers to Invalidate:**
    *   `planningProvider`
    *   *Note: Invalidate `habitsProvider` if habits are editable from here.*

### 5. Progress Analytics Screen (`apps/central_hub/lib/screens/progress_analytics_screen.dart`)
*   **Target View:** The main `ListView` displaying charts and stats.
*   **Providers to Invalidate:**
    *   `analyticsProvider`

### 6. Friends List Screen (`apps/central_hub/lib/screens/friends_list_screen.dart`)
*   **Target View:** The `ListView.separated` showing the list of friends.
*   **Providers to Invalidate:**
    *   `friendsProvider`

### 7. Public Profile Screen (`apps/central_hub/lib/screens/public_profile_screen.dart`)
*   **Target View:** The main `CustomScrollView` displaying user info, stats, and medals.
*   **Providers to Invalidate:**
    *   `publicStatsProvider(profile.id)`
    *   `publicAchievementsProvider(userId)`
    *   `publicMissionMedalsProvider(userId)`
    *   `friendsProvider`

### 8. Goal Stats Screen (`apps/central_hub/lib/screens/goal_stats_screen.dart`)
*   **Target View:** The main `ListView` showing goal statistics.
*   **Providers to Invalidate:**
    *   `planningProvider`
    *   `habitsProvider`

### 9. User Search Screen (`apps/central_hub/lib/screens/user_search_screen.dart`)
*   **Target View:** The `ListView.separated` showing search results.
*   **Providers to Invalidate:**
    *   `userSearchProvider(query)` (Invalidating this will trigger a refetch if active)

### 10. Interface Hub Screen (`apps/central_hub/lib/screens/interface_hub_screen.dart`)
*   **Target View:** The main scrollable area of the shop/inventory.
*   **Providers to Invalidate:**
    *   `inventoryProvider`
    *   `userProfileProvider`
    *   `avatarFramesProvider`
    *   `profileBackgroundsProvider`
    *   `statStylesProvider`

## Verification
*   Verify that swiping down triggers the `RefreshIndicator` on all listed screens.
*   Ensure that the `RefreshIndicator` works correctly even when the list is small or empty.
*   Confirm that data updates correctly from Supabase after a manual refresh.
*   Ensure UI remains responsive during the refresh process.
