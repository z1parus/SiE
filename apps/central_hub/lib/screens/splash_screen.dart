import 'dart:math' as math;
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

    // Extended to ~2.1s; collapse further and drop the scale movement
    // when the OS "reduce motion" setting is on.
    final motion = SieMotion.enabled(context);
    _ctrl.duration = Duration(milliseconds: motion ? 2100 : 500);

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
            body: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HexGridPainter(
                      color: textColor.withOpacity(0.03),
                      glowColor: const Color(0xFF4ECDC4),
                    ),
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: ScaleTransition(
                      scale: _textScale,
                      child: Semantics(
                        label: t.splash.a11y.loading,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/icons/orb_splash.png',
                              width: 260,
                              height: 260,
                            ),
                            const SizedBox(height: 32),
                            Text(
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

class _HexGridPainter extends CustomPainter {
  final Color color;
  final Color glowColor;

  _HexGridPainter({required this.color, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double radius = 30.0;
    final double width = math.sqrt(3) * radius;
    final double height = 2 * radius;

    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final random = math.Random(42);

    for (double y = -height; y < size.height + height; y += height * 0.75) {
      bool offset = (y / (height * 0.75)).round() % 2 != 0;
      for (double x = -width; x < size.width + width; x += width) {
        double cx = x + (offset ? width / 2 : 0);
        double cy = y;

        final path = Path();
        for (int i = 0; i < 6; i++) {
          double angle = math.pi / 180 * (60 * i - 30);
          double px = cx + radius * math.cos(angle);
          double py = cy + radius * math.sin(angle);
          if (i == 0) path.moveTo(px, py);
          else path.lineTo(px, py);
        }
        path.close();
        canvas.drawPath(path, paint);

        if (random.nextDouble() > 0.96) {
          int vIndex = random.nextInt(6);
          double angle = math.pi / 180 * (60 * vIndex - 30);
          double px = cx + radius * math.cos(angle);
          double py = cy + radius * math.sin(angle);
          canvas.drawCircle(Offset(px, py), 3.0, glowPaint);
          canvas.drawCircle(Offset(px, py), 1.0, Paint()..color = glowColor.withOpacity(0.8));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexGridPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.glowColor != glowColor;
  }
}
