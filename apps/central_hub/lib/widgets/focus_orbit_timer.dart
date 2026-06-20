import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tangled-orbit countdown visual shared by the focus preview card and the full
/// focus timer screen.
///
/// The form is a SINGLE continuous interwoven line — one ribbon wound several
/// times at slowly rotating angles so it reads as four interlocking rings of
/// semi-transparent tube (no loose ends, the path closes seamlessly). A leading
/// arrow travels that line clockwise and completes the whole route every
/// 60 seconds — regardless of how long the running session is set for — trailing
/// a comet of glowing dots. The remaining time floats in the centre.
class FocusOrbitTimer extends StatefulWidget {
  const FocusOrbitTimer({
    super.key,
    required this.size,
    required this.timeText,
    required this.gold,
    required this.gold2,
    required this.glass,
    this.subLabel,
    this.motion = true,
    this.centerFontSize = 26,
    this.glow = true,
  });

  final double size;

  /// Centre readout (remaining time / configured minutes).
  final String timeText;

  /// Small caption under the readout (e.g. "Min").
  final String? subLabel;

  /// Primary tube colour and its lighter companion (app gold gradient).
  final Color gold;
  final Color gold2;

  /// Glass/highlight tint (white on dark, cool slate on light).
  final Color glass;

  final bool motion;
  final double centerFontSize;
  final bool glow;

  @override
  State<FocusOrbitTimer> createState() => _FocusOrbitTimerState();
}

class _FocusOrbitTimerState extends State<FocusOrbitTimer>
    with SingleTickerProviderStateMixin {
  // The arrow traverses the full route once every 60s, independent of the
  // running session length — it's a decorative heartbeat, not a progress dial.
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop =
        AnimationController(vsync: this, duration: const Duration(seconds: 60));
  }

  void _sync() {
    if (widget.motion) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
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
    if (widget.motion != old.motion) _sync();
  }

  @override
  void dispose() {
    _loop.dispose();
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
          // The arrow rides a steady 60s loop — always, idle or running.
          AnimatedBuilder(
            animation: _loop,
            builder: (_, _) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _OrbitPainter(
                arrowP: _loop.value,
                gold: widget.gold,
                gold2: widget.gold2,
                glass: widget.glass,
                glow: widget.glow,
              ),
            ),
          ),
          // Floating centre readout + caption.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (widget.subLabel != null) ...[
                SizedBox(height: widget.centerFontSize * 0.12),
                Text(
                  widget.subLabel!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: widget.centerFontSize * 0.32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double arrowP; // 0..1 arrow route position
  final Color gold;
  final Color gold2;
  final Color glass;
  final bool glow;

  const _OrbitPainter({
    required this.arrowP,
    required this.gold,
    required this.gold2,
    required this.glass,
    required this.glow,
  });

  // One ribbon wound [_windings] times while its orientation makes a FULL turn,
  // so the line closes seamlessly (no loose ends) and overlaps into four
  // interlocking rings (ellipse symmetry folds 8 windings into 4 orientations).
  static const _windings = 8;

  /// Point on the woven ribbon at route fraction [u] (0..1).
  Offset _at(Offset c, double rx, double ry, double u) {
    final theta = 2 * math.pi * _windings * u;
    final phi = 2 * math.pi * u; // full orientation turn → closed loop
    final x = rx * math.cos(theta);
    final y = ry * math.sin(theta);
    return Offset(
      c.dx + x * math.cos(phi) - y * math.sin(phi),
      c.dy + x * math.sin(phi) + y * math.cos(phi),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rx = r * 0.92;
    final ry = r * 0.50;
    final tube = r * 0.058;

    // Build the single continuous ribbon path.
    final path = Path();
    const steps = 600;
    for (var i = 0; i <= steps; i++) {
      final p = _at(c, rx, ry, i / steps);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close(); // seamless closed ribbon — no start/end

    // Tube body (gold gradient) + soft glow.
    final bounds = Rect.fromCircle(center: c, radius: r);
    final body = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = tube
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          gold2.withValues(alpha: 0.32),
          gold.withValues(alpha: 0.16),
        ],
      ).createShader(bounds);
    if (glow) body.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    canvas.drawPath(path, body);

    // Glossy white sheen running along the ribbon.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tube * 0.22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = glass.withValues(alpha: 0.42),
    );

    // Leading arrow + comet trail, travelling the same ribbon.
    _drawArrow(canvas, c, rx, ry, r);
  }

  void _drawArrow(Canvas canvas, Offset c, double rx, double ry, double r) {
    final color = Color.lerp(gold2, Colors.white, 0.4)!;

    // Comet trail of brightening dots following the head along the closed
    // ribbon (wraps past the seam so there's never a gap).
    const trail = 20;
    for (var k = trail; k >= 1; k--) {
      final u = (arrowP - k * 0.006) % 1.0;
      final p = _at(c, rx, ry, u < 0 ? u + 1 : u);
      final a = (1 - k / trail) * 0.9;
      final paint = Paint()..color = color.withValues(alpha: a);
      if (glow) paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawCircle(p, 1.9, paint);
    }

    final head = _at(c, rx, ry, arrowP);
    final ahead = _at(c, rx, ry, (arrowP + 0.004) % 1.0);
    var dir = ahead - head;
    final d = dir.distance;
    dir = d == 0 ? const Offset(1, 0) : dir / d;

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
      old.arrowP != arrowP ||
      old.gold != gold ||
      old.gold2 != gold2 ||
      old.glass != glass ||
      old.glow != glow;
}