import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ecosystem Pillar 2 — "Operative State" (Тонус / Readiness).
///
/// A single 0–100 signal of how ready/energised the operative is. Practices
/// (breathing/meditation) restore it; deep work drains it; habits/tasks keep it
/// up. Between events it drifts back toward a neutral baseline. It's a local,
/// moment-to-moment signal (no history, no server sync) surfaced as gentle
/// hints in the Operational Brief.
enum OperativeBand { low, mid, high }

class OperativeState {
  final int value; // 0..100, already decayed to "now"
  const OperativeState(this.value);

  OperativeBand get band =>
      value < 40 ? OperativeBand.low : (value < 76 ? OperativeBand.mid : OperativeBand.high);

  double get fraction => (value / 100).clamp(0.0, 1.0);
}

// Tuning — kept in one place for easy calibration.
const int kOperativeBaseline = 60;
const double _kDecayPerHour = 8.0; // points/hour drift toward the baseline

// Source deltas.
const int kOpDeltaBreathing = 12;
const int kOpDeltaMeditation = 15;
const int kOpDeltaFocus = -12; // deep work spends readiness
const int kOpDeltaHabit = 4;
const int kOpDeltaTask = 4;

const _kValueKey = 'op_state_value';
const _kUpdatedKey = 'op_state_updated_ms';

class OperativeStateNotifier extends AsyncNotifier<OperativeState> {
  @override
  Future<OperativeState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return OperativeState(_decayedValue(prefs));
  }

  /// Current value with time-based drift toward the baseline applied.
  int _decayedValue(SharedPreferences prefs) {
    final raw = prefs.getInt(_kValueKey);
    final updated = prefs.getInt(_kUpdatedKey);
    if (raw == null || updated == null) return kOperativeBaseline;
    final hours =
        (DateTime.now().millisecondsSinceEpoch - updated) / 3600000.0;
    if (hours <= 0) return raw.clamp(0, 100);
    final drift = _kDecayPerHour * hours;
    if (raw > kOperativeBaseline) {
      return (raw - drift).clamp(kOperativeBaseline.toDouble(), 100).round();
    }
    if (raw < kOperativeBaseline) {
      return (raw + drift).clamp(0, kOperativeBaseline.toDouble()).round();
    }
    return raw;
  }

  /// Applies a delta (from a finished activity) on top of the decayed value.
  Future<void> applyDelta(int delta) async {
    if (delta == 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = _decayedValue(prefs);
    final next = (current + delta).clamp(0, 100);
    await prefs.setInt(_kValueKey, next);
    await prefs.setInt(_kUpdatedKey, DateTime.now().millisecondsSinceEpoch);
    state = AsyncData(OperativeState(next));
  }
}

final operativeStateProvider =
    AsyncNotifierProvider<OperativeStateNotifier, OperativeState>(
  OperativeStateNotifier.new,
);

/// Best-effort delta application from the practice/planning/habit modules.
Future<void> bumpOperativeState(Ref ref, int delta) async {
  try {
    await ref.read(operativeStateProvider.notifier).applyDelta(delta);
  } catch (_) {
    // never blocks the activity flow
  }
}
