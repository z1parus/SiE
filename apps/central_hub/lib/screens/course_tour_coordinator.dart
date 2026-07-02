import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import '../main.dart' show rootNavigatorKey;
import 'mission_detail_screen.dart';
import 'habit_tracker_screen.dart';
import 'habits_overview_screen.dart';

/// App-side coordinator for module courses that span multiple screens.
///
/// Mounted once above the navigator (in [MaterialApp.builder]). It watches the
/// tour state and pushes the screens a course's later steps live on so they
/// have something to spotlight, then pops back when the course leaves those
/// steps or ends:
///
///  * Planning — pushes the mission-detail screen (creating a throwaway demo
///    mission when the user has none).
///  * Habits — ensures at least one habit exists (spinning up a demo "Drink
///    water" when empty), then pushes the habit-detail screen (steps 6-8) and
///    the habits-overview screen (step 9).
///
/// The List/Map switch inside mission detail, the forced view mode in the
/// habit tracker and all target keys are handled by the screens themselves.
class CourseTourCoordinator extends ConsumerStatefulWidget {
  const CourseTourCoordinator({super.key});

  @override
  ConsumerState<CourseTourCoordinator> createState() =>
      _CourseTourCoordinatorState();
}

class _CourseTourCoordinatorState extends ConsumerState<CourseTourCoordinator> {
  bool _detailPushed = false;
  bool _busy = false;
  String? _demoGoalId;

  // Habits course state.
  TourScreen? _habitsPushed; // habitDetail | habitsOverview | null
  String? _demoHabitId;

  @override
  Widget build(BuildContext context) {
    ref.listen<TourState>(tourControllerProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    });
    return const SizedBox.shrink();
  }

  Future<void> _sync() async {
    if (!mounted || _busy) return;
    final st = ref.read(tourControllerProvider);
    final controller = ref.read(tourControllerProvider.notifier);

    if (st.type == TourType.habits) {
      await _syncHabits(st, controller);
      return;
    }

    final isPlanning = st.type == TourType.planning && st.isActive;
    final needsDetail = isPlanning &&
        !st.isCompleting &&
        controller.currentScreen != TourScreen.primary;

    if (needsDetail && !_detailPushed) {
      await _pushDetail();
    } else if ((!needsDetail) && _detailPushed) {
      _popDetail();
    }
  }

  // ── Habits course ───────────────────────────────────────────────────────────
  Future<void> _syncHabits(
    TourState st,
    TourController controller,
  ) async {
    // Hold the busy lock for the whole reconcile, including the async demo
    // creation, so overlapping tour-state events can't double-create or
    // double-push.
    _busy = true;
    try {
      // Which screen the current step wants on top of the habit tracker.
      final want = (st.isActive && !st.isCompleting)
          ? controller.currentScreen
          : TourScreen.primary;

      // On activation, make sure there's a habit to spotlight (steps 3, 6-8).
      if (st.isActive) {
        await _ensureDemoHabit(controller);
      }

      final target =
          (want == TourScreen.habitDetail || want == TourScreen.habitsOverview)
              ? want
              : null; // primary → nothing pushed

      if (_habitsPushed == target) {
        // Course ended — forget the demo so a later replay re-checks emptiness.
        if (!st.isActive) _demoHabitId = null;
        return;
      }

      final nav = rootNavigatorKey.currentState;
      if (nav == null) return;

      // Pop whatever module screen is currently up, then push the desired one.
      if (_habitsPushed != null && nav.canPop()) nav.pop();
      _habitsPushed = null;
      if (!st.isActive) _demoHabitId = null;

      if (target == TourScreen.habitDetail) {
        final habit = _firstHabit();
        if (habit == null) return;
        _habitsPushed = TourScreen.habitDetail;
        nav.push(MaterialPageRoute(
          builder: (_) => HabitDetailScreen(habit: habit),
        ));
      } else if (target == TourScreen.habitsOverview) {
        _habitsPushed = TourScreen.habitsOverview;
        nav.push(MaterialPageRoute(
          builder: (_) => const HabitsOverviewScreen(),
        ));
      }
    } finally {
      _busy = false;
    }
  }

  Habit? _firstHabit() {
    final habits = ref.read(habitsProvider).valueOrNull?.habits ?? const [];
    return habits.isNotEmpty ? habits.first : null;
  }

  Future<void> _ensureDemoHabit(TourController controller) async {
    if (_demoHabitId != null) return; // already created this run
    final habits = ref.read(habitsProvider).valueOrNull?.habits;
    if (habits == null || habits.isNotEmpty) return; // user already has habits

    final notifier = ref.read(habitsProvider.notifier);
    final ok = await notifier.addHabit(
      title: t.courseHabits.demoName,
      kind: 'binary',
      polarity: 'build',
      area: LifeArea.health,
      schedule: 'daily',
      color: '#C8A84B',
    );
    if (!ok) return;

    final after = ref.read(habitsProvider).valueOrNull?.habits ?? const [];
    final demo = after
        .where((h) => h.title == t.courseHabits.demoName)
        .cast<Habit?>()
        .firstWhere((_) => true, orElse: () => null);
    if (demo != null) {
      _demoHabitId = demo.id;
      controller.setExtraAction(t.courseHabits.deleteDemo, () {
        final id = _demoHabitId;
        if (id != null) {
          ref.read(habitsProvider.notifier).deleteHabit(id);
          _demoHabitId = null;
        }
      });
    }
  }

  Future<void> _pushDetail() async {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    _busy = true;
    try {
      final notifier = ref.read(planningProvider.notifier);
      var goals = ref.read(planningProvider).valueOrNull?.goals ?? const [];

      Goal? goal = goals.isNotEmpty ? goals.first : null;
      if (goal == null) {
        // No missions — spin up a throwaway demo so the detail steps have a
        // target, and wire its deletion onto the completion card.
        final id = await notifier.addGoal(
          name: t.coursePlanning.demoName,
          colorHex: '#C8A84B',
        );
        if (id != null) {
          _demoGoalId = id;
          goals = ref.read(planningProvider).valueOrNull?.goals ?? const [];
          goal = goals.cast<Goal?>().firstWhere((g) => g?.id == id,
              orElse: () => goals.isNotEmpty ? goals.first : null);
          ref.read(tourControllerProvider.notifier).setExtraAction(
            t.coursePlanning.deleteDemo,
            () {
              final demoId = _demoGoalId;
              if (demoId != null) {
                ref.read(planningProvider.notifier).deleteGoal(demoId);
                _demoGoalId = null;
              }
            },
          );
        }
      }

      if (goal == null) return;
      _detailPushed = true;
      // Don't await — the future only completes when the route is popped, which
      // would hold the busy lock for the whole detail-screen lifetime.
      nav.push(MaterialPageRoute(
        builder: (_) => MissionDetailScreen(goal: goal!),
      ));
    } finally {
      _busy = false;
    }
  }

  void _popDetail() {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    _detailPushed = false;
    if (nav.canPop()) nav.pop();
  }
}
