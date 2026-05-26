import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

class SieSplashScreen extends ConsumerStatefulWidget {
  const SieSplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<SieSplashScreen> createState() => _SieSplashScreenState();
}

class _SieSplashScreenState extends ConsumerState<SieSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Phase 1: text fade+scale  0.00 → 0.43  (≈1200 ms)
  late final Animation<double> _textOpacity;
  late final Animation<double> _textScale;

  // Phase 3: full-screen fade-out  0.79 → 1.00  (≈600 ms)
  late final Animation<double> _screenOpacity;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.43, curve: Curves.easeOut),
      ),
    );

    _textScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.43, curve: Curves.easeOutCubic),
      ),
    );

    _screenOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.79, 1.0, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sieMode =
        ref.watch(sieThemeModeProvider).valueOrNull ?? SieThemeMode.cosmicLiquidGlass;

    final bgColor = switch (sieMode) {
      SieThemeMode.cosmicLiquidGlass => const Color(0xFF0A0E1A),
      SieThemeMode.classicDark       => SieTheme.cdBackground,
      SieThemeMode.classicLight      => SieTheme.clBackground,
    };

    final textColor = switch (sieMode) {
      SieThemeMode.cosmicLiquidGlass => const Color(0xFFF0FAFF),
      SieThemeMode.classicDark       => SieTheme.cdTextPrimary,
      SieThemeMode.classicLight      => SieTheme.clTextPrimary,
    };

    final glowColor = switch (sieMode) {
      SieThemeMode.cosmicLiquidGlass => const Color(0xFF00E5FF),
      SieThemeMode.classicDark       => SieTheme.cdAccent,
      SieThemeMode.classicLight      => SieTheme.clAccent,
    };

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _screenOpacity.value,
          child: Scaffold(
            backgroundColor: bgColor,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (sieMode == SieThemeMode.cosmicLiquidGlass)
                  const SieSpaceBackground(),
                Center(
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: ScaleTransition(
                      scale: _textScale,
                      child: Text(
                        'SiE',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 12,
                          color: textColor,
                          shadows: sieMode == SieThemeMode.cosmicLiquidGlass
                              ? [
                                  Shadow(
                                    color: glowColor.withAlpha(230),
                                    blurRadius: 12,
                                  ),
                                  Shadow(
                                    color: glowColor.withAlpha(160),
                                    blurRadius: 32,
                                  ),
                                  Shadow(
                                    color: glowColor.withAlpha(80),
                                    blurRadius: 72,
                                  ),
                                  Shadow(
                                    color: const Color(0xFF7C3AED).withAlpha(100),
                                    blurRadius: 120,
                                  ),
                                ]
                              : [
                                  Shadow(
                                    color: glowColor.withAlpha(100),
                                    blurRadius: 20,
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
