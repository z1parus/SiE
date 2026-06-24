import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'breathing_format.dart';
import 'session_orb_painters.dart';

/// Vertical journal of every breathing session, newest first. Each session is a
/// uniform card; the cards are strung together by a softly-pulsing neon-gold
/// timeline (the SiE gold) running down the left gutter.
class BreathingJournalScreen extends ConsumerStatefulWidget {
  const BreathingJournalScreen({super.key});

  @override
  ConsumerState<BreathingJournalScreen> createState() =>
      _BreathingJournalScreenState();
}

class _BreathingJournalScreenState extends ConsumerState<BreathingJournalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final async = ref.watch(breathingJournalProvider);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(c: c),
              Expanded(
                child: async.when(
                  loading: () =>
                      Center(child: CircularProgressIndicator(color: kRimGold)),
                  error: (_, _) => _Empty(
                    c: c,
                    icon: Icons.cloud_off_outlined,
                    text: 'Не удалось загрузить журнал практик',
                  ),
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return _Empty(
                        c: c,
                        icon: Icons.menu_book_outlined,
                        text: 'Здесь появятся ваши практики дыхания.\n'
                            'Завершите первую сессию, чтобы начать журнал.',
                      );
                    }
                    return RefreshIndicator(
                      color: kRimGold,
                      backgroundColor: c.isLightMode ? Colors.white : c.surface,
                      onRefresh: () async {
                        ref.invalidate(breathingJournalProvider);
                        await ref.read(breathingJournalProvider.future);
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                        itemCount: sessions.length,
                        itemBuilder: (_, i) => _JournalTile(
                          session: sessions[i],
                          c: c,
                          pulse: _pulseCtrl,
                          isFirst: i == 0,
                          isLast: i == sessions.length - 1,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.c});
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary, size: 22),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Журнал практик',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.air_rounded, size: 20, color: kRimGold.withValues(alpha: 0.9)),
        ],
      ),
    );
  }
}

// ── Journal tile (timeline gutter + uniform card) ──────────────

class _JournalTile extends StatelessWidget {
  const _JournalTile({
    required this.session,
    required this.c,
    required this.pulse,
    required this.isFirst,
    required this.isLast,
  });

  final BreathingSession session;
  final SieColors c;
  final Animation<double> pulse;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pulsing gold timeline gutter.
          SizedBox(
            width: 34,
            child: AnimatedBuilder(
              animation: pulse,
              builder: (_, _) => CustomPaint(
                painter: _TimelinePainter(
                  t: pulse.value,
                  isFirst: isFirst,
                  isLast: isLast,
                  isDark: !c.isLightMode,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SessionCard(session: session, c: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.t,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
  });

  final double t; // 0..1 pulse
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  // Where the node sits vertically — aligned with the card's header row.
  static const double _nodeY = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final glow = 0.35 + 0.45 * t; // pulsing intensity

    final linePaint = Paint()
      ..color = kRimGold.withValues(alpha: isDark ? 0.32 : 0.45)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = kRimGold.withValues(alpha: glow * (isDark ? 0.55 : 0.30))
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final top = isFirst ? _nodeY : 0.0;
    final bottom = isLast ? _nodeY : size.height;

    for (final p in [glowPaint, linePaint]) {
      canvas.drawLine(Offset(cx, top), Offset(cx, bottom), p);
    }

    // Node halo (pulsing).
    canvas.drawCircle(
      Offset(cx, _nodeY),
      6 + 3 * t,
      Paint()
        ..color = kRimGold.withValues(alpha: glow * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Node core.
    canvas.drawCircle(
      Offset(cx, _nodeY),
      4,
      Paint()..color = kRimGold,
    );
    canvas.drawCircle(
      Offset(cx, _nodeY),
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = kRimLight.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.t != t || old.isFirst != isFirst || old.isLast != isLast;
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.c});
  final BreathingSession session;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    final hasReflection = session.calmness != null ||
        session.confidence != null ||
        (session.moodEmoji != null && session.moodEmoji!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + time + mood.
          Row(
            children: [
              Text(
                fmtJournalDate(session.completedAt),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmtClock(session.completedAt),
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              Text(
                (session.moodEmoji != null && session.moodEmoji!.isNotEmpty)
                    ? session.moodEmoji!
                    : '·',
                style: const TextStyle(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Practice metrics.
          Row(
            children: [
              _Metric(
                c: c,
                icon: Icons.air_rounded,
                value: '${session.breaths}',
                label: breathsWord(session.breaths),
              ),
              _MetricDivider(c: c),
              _Metric(
                c: c,
                icon: Icons.hourglass_bottom_rounded,
                value: fmtDuration(session.longestHoldSeconds),
                label: 'задержка',
              ),
              _MetricDivider(c: c),
              _Metric(
                c: c,
                icon: Icons.timer_outlined,
                value: fmtDuration(session.durationSeconds),
                label: 'время',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reflection levels (uniform height: always rendered).
          Row(
            children: [
              Expanded(
                child: _LevelBar(
                  c: c,
                  label: 'Спокойствие',
                  value: session.calmness,
                  accent: c.accentSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LevelBar(
                  c: c,
                  label: 'Уверенность',
                  value: session.confidence,
                  accent: c.accent,
                ),
              ),
            ],
          ),
          if (!hasReflection) ...[
            const SizedBox(height: 2),
            Text(
              'Без оценки состояния',
              style: TextStyle(
                color: c.textSecondary.withValues(alpha: 0.5),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.c,
      required this.icon,
      required this.value,
      required this.label});
  final SieColors c;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 17, color: c.textSecondary),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 1),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.c});
  final SieColors c;
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: c.border);
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({
    required this.c,
    required this.label,
    required this.value,
    required this.accent,
  });
  final SieColors c;
  final String label;
  final int? value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: c.textSecondary, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              value == null ? '—' : '$value',
              style: TextStyle(
                color: value == null ? c.textSecondary : accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: v / 10,
            minHeight: 3,
            backgroundColor: c.border,
            valueColor: AlwaysStoppedAnimation(
                value == null ? c.border : accent.withValues(alpha: 0.85)),
          ),
        ),
      ],
    );
  }
}

// ── Empty ──────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({required this.c, required this.icon, required this.text});
  final SieColors c;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.textSecondary.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: c.textSecondary, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
