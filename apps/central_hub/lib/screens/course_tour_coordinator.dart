import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import '../main.dart' show rootNavigatorKey;
import 'mission_detail_screen.dart';

/// App-side coordinator for module courses that span multiple screens.
///
/// Mounted once above the navigator (in [MaterialApp.builder]). It watches the
/// tour state and, for the Planning course, pushes the mission-detail screen
/// (creating a throwaway demo mission when the user has none) so the later
/// steps have something to spotlight, then pops back when the course leaves
/// those steps or ends. The List/Map switch inside mission detail and all
/// target keys are handled by the screens themselves.
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

  @override
  Widget build(BuildContext context) {
    ref.listen<TourState>(tourControllerProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    });
    return const SizedBox.shrink();
  }

  Future<void> _sync() async {
    if (!mounted || _busy) return;
    final st = ref.read(tourControllerProvider);
    final controller = ref.read(tourControllerProvider.notifier);

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
