import 'package:flutter/widgets.dart';

/// Motion design tokens + reduce-motion support (Stage 0 — design system).
///
/// Honours the OS "reduce motion" / "remove animations" accessibility setting
/// via [MediaQuery.disableAnimationsOf]. Continuous, looping or decorative
/// animations (orb pulses, heartbeats, shimmers) should be gated on
/// [SieMotion.enabled] so vestibular-sensitive users — and battery — are
/// spared. Functional, short transitions may keep running but are still
/// collapsed to zero duration when motion is disabled.
abstract final class SieMotion {
  /// Standard durations — prefer these over magic millisecond literals.
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Whether non-essential animation should play for the current context.
  static bool enabled(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);

  /// Returns [d] when motion is enabled, otherwise [Duration.zero] so
  /// `AnimatedFoo`/implicit transitions resolve instantly.
  static Duration duration(BuildContext context, Duration d) =>
      enabled(context) ? d : Duration.zero;
}
