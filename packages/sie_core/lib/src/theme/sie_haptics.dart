import 'package:flutter/services.dart';

/// Centralised haptic feedback vocabulary (Stage 0 — design system).
///
/// Keeps tactile feedback consistent and intentional across the app instead of
/// scattering raw [HapticFeedback] calls. Use the semantic helper that matches
/// the *meaning* of the interaction, not a specific physical strength.
abstract final class SieHaptics {
  /// Discrete selection: chips, tabs, segmented toggles, picker steps.
  static void selection() => HapticFeedback.selectionClick();

  /// A successful, completed action: session finished, purchase applied.
  static void success() => HapticFeedback.mediumImpact();

  /// A blocked or invalid action: locked day, disabled control tapped.
  static void warning() => HapticFeedback.heavyImpact();

  /// Start of a heavyweight gesture: long-press menu, drag pick-up.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Subtle confirmation for lightweight taps.
  static void light() => HapticFeedback.lightImpact();
}
