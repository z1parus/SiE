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

  const TourStep({
    required this.id,
    required this.title,
    required this.body,
    this.tabIndex = 1,
    this.targetKey,
    this.position = TargetPosition.auto,
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

  @override
  TourState build() => TourState.initial;

  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  GlobalKey? existingKey(String id) => _keys[id];

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
      // Module courses are registered in their respective stages.
      case TourType.planning:
      case TourType.habits:
      case TourType.focus:
      case TourType.breathing:
        return const [];
    }
  }

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
    state = TourState.initial;
  }

  /// Finish and persist the "seen" flag for the active tour/course.
  void finish() {
    final type = state.type;
    state = TourState.initial;
    if (type == TourType.app) {
      ref.read(userProfileProvider.notifier).markTourSeen();
    }
    // Course "seen" flags are recorded in their respective stages.
  }
}

final tourControllerProvider =
    NotifierProvider<TourController, TourState>(TourController.new);
