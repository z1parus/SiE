import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tangled-orbit countdown visual shared by the focus preview card and the full
/// focus timer screen.
///
/// A knot of translucent gold orbit rings with glowing dotted tracks. A leading
/// arrow travels clockwise along the route once over the whole session (so a
/// 1-minute timer completes the loop in a minute, an hour timer in an hour),
/// and the remaining time floats in the centre with a soft drop shadow.
class FocusOrbitTimer extends StatefulWidget {
  const FocusOrbitTimer({
    super.key,
    required this.size,
    required this.timeText,
    required this.gold,
    required this.gold2,
    required this.glass,
    this.progress = 0.0,
    this.demo = false,
    this.motion = true,
    this.centerFontSize = 26,
    this.glow = true,
  });

  final double size;

  /// Centre readout (remaining time / configured minutes).
  final String timeText;

  /// Primary tube colour and its lighter companion (app gold gradient).
  final Color gold;
  final Color gold2;

  /// Glass/highlight tint (white on dark, cool slate on light).
  final Color glass;

  /// Route completion 0..1 (elapsed fraction) for the leading arrow. Ignored
  /// when [demo] is true.
  final double progress;

  /// Preview mode — the arrow loops continuously to advertise the motion.
  final bool demo;

  final bool motion;
  final double centerFontSize;
  final bool glow;

  @override
  State<FocusOrbitTimer> createState() => _FocusOrbitTimerState();
}

class _FocusOrbitTimerState extends State<FocusOrbitTimer>
    with TickerProviderStateMixin {
  late final AnimationController _flow; // dotted-track shimmer
  late final AnimationController _demo; // preview arrow loop

  @override
  void initState() {
    super.initState();
    _flow =
        AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _demo =
        AnimationController(vsync: this, duration: const Duration(seconds: 12));
  }

  void _sync() {
    if (widget.motion) {
      if (!_flow.isAnimating) _flow.repeat();
      if (widget.demo) {
        if (!_demo.isAnimating) _demo.repeat();
      } else {
        _demo.stop();
      }
    } else {
      _flow.stop();
      _demo.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant FocusOrbitTimer old) {
    super.didUpdateWidget(old);
    if (widget.demo != old.demo || widget.motion != old.motion) _sync();
  }

  @override
  void dispose() {
    _flow.dispose();
    _demo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Smoothly interpolate the live progress between per-second updates.
          TweenAnimationBuilder<double>(
            tween: Tween(end: widget.demo ? 0.0 : widget.progress.clamp(0.0, 1.0)),
            duration: widget.motion
                ? const Duration(milliseconds: 700)
                : Duration.zero,
            curve: Curves.linear,
            builder: (_, liveP, _) {
              return AnimatedBuilder(
                animation: Listenable.merge([_flow, _demo]),
                builder: (_, _) {
                  final arrowP = widget.demo ? _demo.value : liveP;
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _OrbitPainter(
                      flow: _flow.value,
                      arrowP: arrowP,
                      gold: widget.gold,
                      gold2: widget.gold2,
                      glass: widget.glass,
                      glow: widget.glow,
                    ),
                  );
                },
              );
            },
          ),
          // Floating centre readout.
          Text(
            widget.timeText,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.centerFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: [
                const Shadow(
                  color: Color(0x73000000),
                  blurRadius: 14,
                  offset: Offset(0, 3),
                ),
                if (widget.glow)
                  Shadow(
                    color: widget.gold.withValues(alpha: 0.45),
                    blurRadius: 24,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Orbit {
  final double rx;
  final double ry;
  final double rot;
  const _Orbit(this.rx, this.ry, this.rot);
}

class _OrbitPainter extends CustomPainter {
  final double flow; // 0..1 dotted shimmer
  final double arrowP; // 0..1 arrow route position
  final Color gold;
  final Color gold2;
  final Color glass;
  final bool glow;

  const _OrbitPainter({
    required this.flow,
    required this.arrowP,
    required this.gold,
    required this.gold2,
    required this.glass,
    required this.glow,
  });

  static const _n = 5; // interlocking rings

  List<_Orbit> _orbits(double r) =>
      [for (var i = 0; i < _n; i++) _Orbit(r * 0.95, r * 0.58, i * math.pi / _n)];

  /// Point on a rotated ellipse at angle [theta].
  Offset _pointOn(Offset c, _Orbit o, double theta) {
    final x = o.rx * math.cos(theta);
    final y = o.ry * math.sin(theta);
    return Offset(
      c.dx + x * math.cos(o.rot) - y * math.sin(o.rot),
      c.dy + x * math.sin(o.rot) + y * math.cos(o.rot),
    );
  }

  /// Unit tangent (direction of increasing theta) on a rotated ellipse.
  Offset _tangent(_Orbit o, double theta) {
    final tx = -o.rx * math.sin(theta);
    final ty = o.ry * math.cos(theta);
    final rx = tx * math.cos(o.rot) - ty * math.sin(o.rot);
    final ry = tx * math.sin(o.rot) + ty * math.cos(o.rot);
    final d = math.sqrt(rx * rx + ry * ry);
    return d == 0 ? Offset.zero : Offset(rx / d, ry / d);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final orbits = _orbits(r);
    final tube = r * 0.055;

    // 1. Translucent gold tubes (interlocking rings).
    for (final o in orbits) {
      final rect = Rect.fromCenter(
          center: Offset.zero, width: o.rx * 2, height: o.ry * 2);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(o.rot);

      final body = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tube
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gold2.withValues(alpha: 0.30),
            gold.withValues(alpha: 0.16),
          ],
        ).createShader(rect);
      if (glow) body.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawOval(rect, body);

      // Glossy white highlight running along the tube.
      canvas.drawOval(
        rect.deflate(tube * 0.26),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = tube * 0.22
          ..strokeCap = StrokeCap.round
          ..color = glass.withValues(alpha: 0.45),
      );
      canvas.restore();
    }

    // 2. Glowing dotted tracks marching along three of the rings.
    final dotColor = Color.lerp(gold2, Colors.white, 0.55)!;
    for (var i = 0; i < _n; i += 2) {
      _drawDots(canvas, c, orbits[i], dotColor, phase: flow + i / _n);
    }

    // 3. Leading arrow travelling the route (one full loop per session).
    _drawArrow(canvas, c, orbits[0], r);
  }

  void _drawDots(Canvas canvas, Offset c, _Orbit o, Color color,
      {required double phase}) {
    const count = 30;
    final base = phase * 2 * math.pi / count;
    for (var k = 0; k < count; k++) {
      final theta = base + k * 2 * math.pi / count;
      final p = _pointOn(c, o, theta);
      final paint = Paint()..color = color.withValues(alpha: 0.55);
      if (glow) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
      canvas.drawCircle(p, 1.5, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset c, _Orbit o, double r) {
    final headTheta = -math.pi / 2 + arrowP * 2 * math.pi;
    final arrowColor = Color.lerp(gold2, Colors.white, 0.4)!;

    // Comet trail of brightening dots leading to the head.
    const trail = 14;
    for (var k = trail; k >= 1; k--) {
      final th = headTheta - k * 0.05;
      final p = _pointOn(c, o, th);
      final a = (1 - k / trail) * 0.85;
      final paint = Paint()..color = arrowColor.withValues(alpha: a);
      if (glow) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawCircle(p, 1.8, paint);
    }

    final head = _pointOn(c, o, headTheta);
    final dir = _tangent(o, headTheta);

    // Bright head.
    final hp = Paint()..color = Colors.white;
    if (glow) hp.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(head, 3.0, hp);

    // Arrowhead wings (pointing along travel).
    final s = r * 0.055;
    Offset wing(double da) {
      final bx = -dir.dx;
      final by = -dir.dy;
      return Offset(
        bx * math.cos(da) - by * math.sin(da),
        bx * math.sin(da) + by * math.cos(da),
      );
    }

    final wp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawLine(head, head + wing(0.5) * s, wp);
    canvas.drawLine(head, head + wing(-0.5) * s, wp);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.flow != flow ||
      old.arrowP != arrowP ||
      old.gold != gold ||
      old.gold2 != gold2 ||
      old.glass != glass ||
      old.glow != glow;
}
