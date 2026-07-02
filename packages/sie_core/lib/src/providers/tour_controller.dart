import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/translations.g.dart';
import 'user_profile_provider.dart';

/// Which interactive tour/course is running. `app` is the general onboarding
/// tour across the four bottom tabs; the rest are per-module courses added in
/// later stages.
enum TourType { app, planning, habits, focus, breathing }

/// Preferred placement of the tooltip card relative to its target.
enum TargetPosition { above, below, auto }

/// Which screen a course step lives on (used by the app-side course
/// coordinator to push/switch screens). App-tour steps ignore this.
enum TourScreen {
  primary,
  missionDetail,
  tacticalMap,
  habitDetail,
  habitsOverview,
}

/// One step of a tour: a highlighted target + an explanatory card.
class TourStep {
  final String id;

  /// Bottom-nav tab this step lives on (app tour). Module courses ignore it.
  final int tabIndex;

  /// Id of the [GlobalKey] of the widget to spotlight. `null` → a centred card
  /// with no spotlight (used for concept-only steps and the final card).
  final String? targetKey;

  final String title;
  final String body;
  final TargetPosition position;

  /// Screen this step lives on (module courses only).
  final TourScreen screen;

  const TourStep({
    required this.id,
    required this.title,
    required this.body,
    this.tabIndex = 1,
    this.targetKey,
    this.position = TargetPosition.auto,
    this.screen = TourScreen.primary,
  });
}

class TourState {
  final TourType type;
  final int currentIndex;
  final bool isActive;

  /// True once the user has advanced past the last step — the final
  /// "tour complete" card is shown instead of a spotlight.
  final bool isCompleting;

  const TourState({
    this.type = TourType.app,
    this.currentIndex = 0,
    this.isActive = false,
    this.isCompleting = false,
  });

  TourState copyWith({
    TourType? type,
    int? currentIndex,
    bool? isActive,
    bool? isCompleting,
  }) =>
      TourState(
        type: type ?? this.type,
        currentIndex: currentIndex ?? this.currentIndex,
        isActive: isActive ?? this.isActive,
        isCompleting: isCompleting ?? this.isCompleting,
      );

  static const initial = TourState();
}

class TourController extends Notifier<TourState> {
  // GlobalKeys are stable for the controller's lifetime — a target attaches its
  // key via [keyFor]; the overlay reads the same key's render box to spotlight.
  final Map<String, GlobalKey> _keys = {};

  // Optional extra action on the completion card (e.g. "delete demo mission"),
  // wired by the app-side course coordinator.
  String? _extraLabel;
  VoidCallback? _extraAction;

  @override
  TourState build() => TourState.initial;

  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  GlobalKey? existingKey(String id) => _keys[id];

  /// The screen the current course step lives on (for the coordinator).
  TourScreen get currentScreen => currentStep?.screen ?? TourScreen.primary;

  // Completion-card copy for the active tour/course.
  String get completeTitle => switch (state.type) {
        TourType.app => t.tour.complete.title,
        TourType.planning => t.coursePlanning.complete.title,
        TourType.habits => t.courseHabits.complete.title,
        TourType.focus => t.courseFocus.complete.title,
        TourType.breathing => t.courseBreathing.complete.title,
      };

  String get completeBody => switch (state.type) {
        TourType.app => t.tour.complete.body,
        TourType.planning => t.coursePlanning.complete.body,
        TourType.habits => t.courseHabits.complete.body,
        TourType.focus => t.courseFocus.complete.body,
        TourType.breathing => t.courseBreathing.complete.body,
      };

  // ── Completion extra action ────────────────────────────────────────────────
  String? get extraLabel => _extraLabel;
  bool get hasExtra => _extraLabel != null && _extraAction != null;

  void setExtraAction(String label, VoidCallback action) {
    _extraLabel = label;
    _extraAction = action;
  }

  void clearExtraAction() {
    _extraLabel = null;
    _extraAction = null;
  }

  void runExtra() {
    _extraAction?.call();
    clearExtraAction();
  }

  // ── Steps ──────────────────────────────────────────────────────────────────
  List<TourStep> get steps => _stepsFor(state.type);

  TourStep? get currentStep {
    final s = steps;
    if (state.currentIndex < 0 || state.currentIndex >= s.length) return null;
    return s[state.currentIndex];
  }

  /// Tab the current step wants the shell on (null when not in an active app
  /// tour or while showing the completion card).
  int? get desiredTab {
    if (!state.isActive || state.isCompleting || state.type != TourType.app) {
      return null;
    }
    return currentStep?.tabIndex;
  }

  List<TourStep> _stepsFor(TourType type) {
    switch (type) {
      case TourType.app:
        return _appSteps;
      case TourType.planning:
        return _planningSteps;
      case TourType.habits:
        return _habitsSteps;
      case TourType.focus:
        return _focusSteps;
      case TourType.breathing:
        return _breathingSteps;
    }
  }

  // Breathing course — 8 steps, all on BreathingExerciseScreen (single screen,
  // no navigation). Steps 3 (phases) and 5 (presets) describe things not
  // visible in the idle state, so they have no target and show a centred
  // concept card.
  List<TourStep> get _breathingSteps => [
        TourStep(
          id: 'breathing_sphere',
          targetKey: 'breathing_sphere',
          title: t.courseBreathing.step1.title,
          body: t.courseBreathing.step1.body,
        ),
        TourStep(
          id: 'breathing_hud',
          targetKey: 'breathing_hud',
          title: t.courseBreathing.step2.title,
          body: t.courseBreathing.step2.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'breathing_phases',
          targetKey: null, // phase elements only exist mid-session
          title: t.courseBreathing.step3.title,
          body: t.courseBreathing.step3.body,
        ),
        TourStep(
          id: 'breathing_settings',
          targetKey: 'breathing_settings',
          title: t.courseBreathing.step4.title,
          body: t.courseBreathing.step4.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'breathing_presets',
          targetKey: null, // lives inside the settings sheet
          title: t.courseBreathing.step5.title,
          body: t.courseBreathing.step5.body,
        ),
        TourStep(
          id: 'breathing_sequences',
          targetKey: 'breathing_sequences',
          title: t.courseBreathing.step6.title,
          body: t.courseBreathing.step6.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'breathing_journal',
          targetKey: 'breathing_journal',
          title: t.courseBreathing.step7.title,
          body: t.courseBreathing.step7.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'breathing_initiate',
          targetKey: 'breathing_initiate',
          title: t.courseBreathing.step8.title,
          body: t.courseBreathing.step8.body,
          position: TargetPosition.above,
        ),
      ];

  // Focus course — 6 steps, all on FocusProtocolScreen (single screen, no
  // navigation). Step 4 targets the task banner, which only exists when a task
  // is bound; with none bound its key resolves to nothing and the overlay shows
  // a centred concept card.
  List<TourStep> get _focusSteps => [
        TourStep(
          id: 'focus_ring',
          targetKey: 'focus_ring',
          title: t.courseFocus.step1.title,
          body: t.courseFocus.step1.body,
        ),
        TourStep(
          id: 'focus_phase',
          targetKey: 'focus_phase',
          title: t.courseFocus.step2.title,
          body: t.courseFocus.step2.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'focus_xp',
          targetKey: 'focus_xp',
          title: t.courseFocus.step3.title,
          body: t.courseFocus.step3.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'focus_task_banner',
          targetKey: 'focus_task_banner',
          title: t.courseFocus.step4.title,
          body: t.courseFocus.step4.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'focus_settings',
          targetKey: 'focus_settings',
          title: t.courseFocus.step5.title,
          body: t.courseFocus.step5.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'focus_start',
          targetKey: 'focus_start',
          title: t.courseFocus.step6.title,
          body: t.courseFocus.step6.body,
          position: TargetPosition.above,
        ),
      ];

  // Habits course — 9 steps across HabitTracker (primary) → HabitDetail →
  // HabitsOverview. `screen` drives the app-side course coordinator, which
  // pushes/pops the detail and overview screens; all target keys are attached
  // by the screens themselves.
  List<TourStep> get _habitsSteps => [
        TourStep(
          id: 'habits_fab',
          screen: TourScreen.primary,
          targetKey: 'habits_fab',
          title: t.courseHabits.step1.title,
          body: t.courseHabits.step1.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'habits_view_toggle',
          screen: TourScreen.primary,
          targetKey: 'habits_view_toggle',
          title: t.courseHabits.step2.title,
          body: t.courseHabits.step2.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'habits_first_card',
          screen: TourScreen.primary,
          targetKey: 'habits_first_card',
          title: t.courseHabits.step3.title,
          body: t.courseHabits.step3.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'habits_routine_buttons',
          screen: TourScreen.primary,
          // The top routine blocks are time-gated and only render when a
          // routine exists, so spotlight the always-present routine button in
          // the bottom bar instead — which is what the copy points to.
          targetKey: 'habits_routine_buttons',
          title: t.courseHabits.step4.title,
          body: t.courseHabits.step4.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'habits_create_stack',
          screen: TourScreen.primary,
          targetKey: 'habits_create_stack',
          title: t.courseHabits.step5.title,
          body: t.courseHabits.step5.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'hd_stats',
          screen: TourScreen.habitDetail,
          targetKey: 'hd_stats',
          title: t.courseHabits.step6.title,
          body: t.courseHabits.step6.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'hd_heatmap',
          screen: TourScreen.habitDetail,
          targetKey: 'hd_heatmap',
          title: t.courseHabits.step7.title,
          body: t.courseHabits.step7.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'hd_journal',
          screen: TourScreen.habitDetail,
          targetKey: 'hd_journal',
          title: t.courseHabits.step8.title,
          body: t.courseHabits.step8.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'ho_week_rate',
          screen: TourScreen.habitsOverview,
          targetKey: 'ho_week_rate',
          title: t.courseHabits.step9.title,
          body: t.courseHabits.step9.body,
          position: TargetPosition.below,
        ),
      ];

  // Planning course — 10 steps across PlanningScreen → MissionDetail (list) →
  // Tactical Map (mission detail's map mode). `screen` drives the coordinator.
  List<TourStep> get _planningSteps => [
        TourStep(
          id: 'planning_fab',
          screen: TourScreen.primary,
          targetKey: 'planning_fab',
          title: t.coursePlanning.step1.title,
          body: t.coursePlanning.step1.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'planning_mode_switch',
          screen: TourScreen.primary,
          targetKey: 'planning_mode_switch',
          title: t.coursePlanning.step2.title,
          body: t.coursePlanning.step2.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'planning_goal_arc',
          screen: TourScreen.primary,
          targetKey: 'planning_goal_arc',
          title: t.coursePlanning.step3.title,
          body: t.coursePlanning.step3.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'md_view_toggle',
          screen: TourScreen.missionDetail,
          targetKey: 'md_view_toggle',
          title: t.coursePlanning.step4.title,
          body: t.coursePlanning.step4.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'md_subgoals_header',
          screen: TourScreen.missionDetail,
          targetKey: 'md_subgoals_header',
          title: t.coursePlanning.step5.title,
          body: t.coursePlanning.step5.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'md_task_checkbox',
          screen: TourScreen.missionDetail,
          targetKey: 'md_task_checkbox',
          title: t.coursePlanning.step6.title,
          body: t.coursePlanning.step6.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'md_ai_button',
          screen: TourScreen.missionDetail,
          targetKey: 'md_ai_button',
          title: t.coursePlanning.step7.title,
          body: t.coursePlanning.step7.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'md_quick_entry',
          screen: TourScreen.missionDetail,
          targetKey: 'md_quick_entry',
          title: t.coursePlanning.step8.title,
          body: t.coursePlanning.step8.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'tm_canvas',
          screen: TourScreen.tacticalMap,
          targetKey: null, // centred card; the map is shown behind
          title: t.coursePlanning.step9.title,
          body: t.coursePlanning.step9.body,
        ),
        TourStep(
          id: 'tm_edit_mode',
          screen: TourScreen.tacticalMap,
          targetKey: null,
          title: t.coursePlanning.step10.title,
          body: t.coursePlanning.step10.body,
        ),
      ];

  // App tour — 7 steps across the four bottom tabs. Built from `t` so it picks
  // up the active locale.
  List<TourStep> get _appSteps => [
        TourStep(
          id: 'xp_bar',
          tabIndex: 1,
          targetKey: 'xp_bar',
          title: t.tour.step1.title,
          body: t.tour.step1.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'branch_carousel',
          tabIndex: 1,
          targetKey: 'branch_carousel',
          title: t.tour.step2.title,
          body: t.tour.step2.body,
          position: TargetPosition.below,
        ),
        TourStep(
          id: 'leaderboard_tile',
          tabIndex: 1,
          targetKey: 'leaderboard_tile',
          title: t.tour.step3.title,
          body: t.tour.step3.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'nav_bar',
          tabIndex: 1,
          targetKey: 'nav_bar',
          title: t.tour.step4.title,
          body: t.tour.step4.body,
          position: TargetPosition.above,
        ),
        TourStep(
          id: 'profile_body',
          tabIndex: 0,
          targetKey: 'profile_body',
          title: t.tour.step5.title,
          body: t.tour.step5.body,
          position: TargetPosition.auto,
        ),
        TourStep(
          id: 'garage_body',
          tabIndex: 2,
          targetKey: 'garage_body',
          title: t.tour.step6.title,
          body: t.tour.step6.body,
          position: TargetPosition.auto,
        ),
        TourStep(
          id: 'leaderboard_body',
          tabIndex: 3,
          targetKey: 'leaderboard_body',
          title: t.tour.step7.title,
          body: t.tour.step7.body,
          position: TargetPosition.auto,
        ),
      ];

  // ── Control ─────────────────────────────────────────────────────────────────
  void start(TourType type) {
    clearExtraAction();
    state = TourState(type: type, currentIndex: 0, isActive: true);
  }

  void next() {
    if (state.isCompleting) {
      finish();
      return;
    }
    final last = steps.length - 1;
    if (state.currentIndex >= last) {
      state = state.copyWith(isCompleting: true);
    } else {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void back() {
    if (state.isCompleting) {
      state = state.copyWith(isCompleting: false);
      return;
    }
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  /// Close without recording completion — the tour can be replayed later.
  void skip() {
    clearExtraAction();
    state = TourState.initial;
  }

  /// Finish and persist the "seen" flag for the active tour/course.
  void finish() {
    final type = state.type;
    clearExtraAction();
    state = TourState.initial;
    switch (type) {
      case TourType.app:
        ref.read(userProfileProvider.notifier).markTourSeen();
      case TourType.planning:
        ref.read(userProfileProvider.notifier).markCourseSeen('planning');
      case TourType.habits:
        ref.read(userProfileProvider.notifier).markCourseSeen('habits');
      case TourType.focus:
        ref.read(userProfileProvider.notifier).markCourseSeen('focus');
      case TourType.breathing:
        ref.read(userProfileProvider.notifier).markCourseSeen('breathing');
    }
  }
}

final tourControllerProvider =
    NotifierProvider<TourController, TourState>(TourController.new);
