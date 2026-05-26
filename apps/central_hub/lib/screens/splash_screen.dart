import 'package:flutter/material.dart';
import 'package:sie_core/sie_core.dart';

class SieSplashScreen extends StatefulWidget {
  const SieSplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SieSplashScreen> createState() => _SieSplashScreenState();
}

class _SieSplashScreenState extends State<SieSplashScreen>
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
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _screenOpacity.value,
          child: Scaffold(
            backgroundColor: const Color(0xFF0A0E1A),
            body: Stack(
              fit: StackFit.expand,
              children: [
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
                          color: const Color(0xFFF0FAFF),
                          shadows: [
                            // Layer 1 — tight cyan core glow
                            Shadow(
                              color: const Color(0xFF00E5FF).withAlpha(230),
                              blurRadius: 12,
                            ),
                            // Layer 2 — mid cyan halo
                            Shadow(
                              color: const Color(0xFF00E5FF).withAlpha(160),
                              blurRadius: 32,
                            ),
                            // Layer 3 — wide cyan bloom
                            Shadow(
                              color: const Color(0xFF00E5FF).withAlpha(80),
                              blurRadius: 72,
                            ),
                            // Layer 4 — deep purple outer aura
                            Shadow(
                              color: const Color(0xFF7C3AED).withAlpha(100),
                              blurRadius: 120,
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
