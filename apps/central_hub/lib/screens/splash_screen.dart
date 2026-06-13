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

  late Animation<double> _textOpacity;
  late Animation<double> _textScale;
  late Animation<double> _screenOpacity;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Trimmed from 2.8s → ~1.6s; collapse further and drop the scale movement
    // when the OS "reduce motion" setting is on.
    final motion = SieMotion.enabled(context);
    _ctrl.duration = Duration(milliseconds: motion ? 1600 : 500);

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _textScale = Tween<double>(begin: motion ? 0.82 : 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _screenOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.72, 1.0, curve: Curves.easeIn),
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
        ref.watch(sieThemeModeProvider).valueOrNull ?? SieThemeMode.classicDark;

    final bgColor = switch (sieMode) {
      SieThemeMode.classicDark  => SieTheme.cdBackground,
      SieThemeMode.classicLight => SieTheme.clBackground,
    };

    final textColor = switch (sieMode) {
      SieThemeMode.classicDark  => SieTheme.cdTextPrimary,
      SieThemeMode.classicLight => SieTheme.clTextPrimary,
    };

    final glowColor = switch (sieMode) {
      SieThemeMode.classicDark  => SieTheme.cdAccent,
      SieThemeMode.classicLight => SieTheme.clAccent,
    };

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _screenOpacity.value,
          child: Scaffold(
            backgroundColor: bgColor,
            body: Center(
              child: FadeTransition(
                opacity: _textOpacity,
                child: ScaleTransition(
                  scale: _textScale,
                  child: Semantics(
                    label: 'SiE — загрузка',
                    child: Text(
                      'SiE',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        color: textColor,
                        shadows: [
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
            ),
          ),
        );
      },
    );
  }
}
