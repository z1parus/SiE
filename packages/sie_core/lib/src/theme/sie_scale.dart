/// Proportional UI scaling so the tightly-spaced, fixed-size design adapts to
/// devices with a different logical width — most importantly Android "Screen
/// zoom" / "Display size" settings, which shrink the logical width in dp and
/// otherwise overflow the layouts.
///
/// The factor is derived from the screen width relative to [referenceWidth]
/// (the width the design is authored for) and applied to sizes via the [num.s]
/// extension. It only ever scales *down* (factor ≤ 1.0), so reference-width and
/// wider devices render pixel-identical to before — zero regression — while
/// narrower / zoomed screens shrink proportionally.
///
/// The factor is held in a static updated once per frame from
/// `MaterialApp.builder` (see [SieScale.update]); same approach as
/// `flutter_screenutil`'s init. Coach-mark spotlighting stays correct because
/// it measures the *actual* (already-scaled) render boxes — unlike a global
/// `Transform`, which would desync the overlay.
class SieScale {
  SieScale._();

  /// Logical width (dp) the design is laid out for.
  static const double referenceWidth = 390.0;

  /// Lower bound — never shrink below this (readability floor).
  static const double minFactor = 0.85;

  /// Upper bound — never upscale (wide screens keep the reference look + extra
  /// margins instead of a blown-up UI).
  static const double maxFactor = 1.0;

  static double _factor = 1.0;

  /// The current proportional scale factor (clamped to [minFactor]..[maxFactor]).
  static double get factor => _factor;

  /// Recompute the factor from the current screen width. Call once per frame
  /// from the app-level builder before the tree is built.
  static void update(double screenWidthDp) {
    if (screenWidthDp <= 0) return;
    _factor = (screenWidthDp / referenceWidth).clamp(minFactor, maxFactor);
  }

  /// Scale a single design value (font size, padding, width, radius, …).
  static double of(num value) => value * _factor;
}

extension SieScaleNum on num {
  /// Proportionally-scaled size. Apply to fonts, paddings, fixed widths/heights,
  /// radii and letter-spacing — not to opacities, fractions or durations.
  double get s => SieScale.of(this);
}
