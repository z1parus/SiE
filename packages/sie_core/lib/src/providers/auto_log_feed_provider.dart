import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ecosystem Pillar 1 (surfacing) — a short, in-memory feed of habits that were
/// auto-completed by module activity, shown in the Operational Brief with an
/// Undo affordance. Session-scoped (clears on restart); most-recent first.
class AutoLogEntry {
  final String habitId;
  final String title;
  final bool isMetric;
  final double delta; // value added for metric habits (0 for binary)
  final DateTime at;

  const AutoLogEntry({
    required this.habitId,
    required this.title,
    required this.isMetric,
    required this.delta,
    required this.at,
  });
}

class AutoLogFeedNotifier extends Notifier<List<AutoLogEntry>> {
  @override
  List<AutoLogEntry> build() => const [];

  void add(AutoLogEntry entry) {
    // Keep the latest per habit, cap the feed length.
    state = [
      entry,
      ...state.where((e) => e.habitId != entry.habitId),
    ].take(5).toList();
  }

  void remove(String habitId) {
    state = state.where((e) => e.habitId != habitId).toList();
  }

  void clear() => state = const [];
}

final autoLogFeedProvider =
    NotifierProvider<AutoLogFeedNotifier, List<AutoLogEntry>>(
  AutoLogFeedNotifier.new,
);
