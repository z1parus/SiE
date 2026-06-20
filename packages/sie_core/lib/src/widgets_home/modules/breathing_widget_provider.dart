import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../local/app_database.dart';
import '../../providers/meditation_stats_provider.dart' show kWidgetZenStreakKey;
import '../../theme/sie_colors.dart';
import '../module_widget_provider.dart';
import '../widget_config.dart';
import '../widget_option_spec.dart';
import '../widget_size_bucket.dart';
import '../widget_theme_bridge.dart';

// Teal palette for the breathing orb (mirrors the in-app session orb).
const _kRimTeal = Color(0xFF4ECDC4);
const _kRimTealLight = Color(0xFF80E8E0);

// ── Data ──────────────────────────────────────────────────────────────────────

class BreathingWidgetData extends WidgetData {
  final int zenStreakDays;
  final int minutesThisWeek;
  final int totalSessions;
  final DateTime? lastSessionAt;
  final String quickPatternId;

  const BreathingWidgetData({
    required this.zenStreakDays,
    required this.minutesThisWeek,
    required this.totalSessions,
    required this.lastSessionAt,
    required this.quickPatternId,
  });

  bool get neverPractised => totalSessions == 0;

  /// Streak is at risk when there was a session yesterday but none today.
  bool get streakAtRisk {
    if (lastSessionAt == null || zenStreakDays == 0) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(
        lastSessionAt!.year, lastSessionAt!.month, lastSessionAt!.day);
    return last.isBefore(today); // last session was before today
  }

  @override
  String get signature =>
      '$zenStreakDays:$minutesThisWeek:$totalSessions:'
      '${lastSessionAt?.millisecondsSinceEpoch ?? 0}:$quickPatternId';
}

// ── Provider ──────────────────────────────────────────────────────────────────

class BreathingWidgetProvider extends ModuleWidgetProvider<BreathingWidgetData> {
  @override
  String get moduleId => 'breathing';
  @override
  String get displayName => 'Дыхание';
  @override
  IconData get glyph => Icons.air;
  @override
  String get androidProviderClass => 'BreathingWidgetProvider';
  @override
  List<WidgetSizeBucket> get supportedSizes => const [
        WidgetSizeBucket.small,
        WidgetSizeBucket.medium,
        WidgetSizeBucket.large,
      ];

  @override
  Future<BreathingWidgetData> loadData(AppDatabase db, WidgetConfig cfg) async {
    final breathing = await db.breathingSessionsForWidget();
    final meditation = await db.meditationSessionsForWidget();

    // Combine completed-at timestamps + durations from both calm practices.
    final stamps = <int>[
      ...breathing.map((s) => s.completedAtMs),
      ...meditation.map((s) => s.completedAtMs),
    ];
    var weekSecs = 0;
    final now = DateTime.now();
    final weekStart =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final weekStartMs = weekStart.millisecondsSinceEpoch;
    for (final s in breathing) {
      if (s.completedAtMs >= weekStartMs) weekSecs += s.durationSeconds;
    }
    for (final s in meditation) {
      if (s.completedAtMs >= weekStartMs) weekSecs += s.durationSeconds;
    }

    DateTime? lastAt;
    if (stamps.isNotEmpty) {
      stamps.sort();
      lastAt = DateTime.fromMillisecondsSinceEpoch(stamps.last);
    }

    // Zen streak: prefer the cached profile value (written online by the stats
    // provider); fall back to a streak derived from the local session history.
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final streak =
        prefs.getInt(kWidgetZenStreakKey) ?? _streakFromStamps(stamps);

    final quickPattern =
        cfg.contentOptions['quickPattern'] as String? ?? 'box';

    return BreathingWidgetData(
      zenStreakDays: streak,
      minutesThisWeek: weekSecs ~/ 60,
      totalSessions: breathing.length + meditation.length,
      lastSessionAt: lastAt,
      quickPatternId: quickPattern,
    );
  }

  /// Consecutive-day streak ending today or yesterday, derived from session
  /// timestamps (millis). Used only when no cached profile streak exists.
  int _streakFromStamps(List<int> stampsMs) {
    if (stampsMs.isEmpty) return 0;
    final days = <int>{}; // day-floor millis
    for (final ms in stampsMs) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      days.add(DateTime(d.year, d.month, d.day).millisecondsSinceEpoch);
    }
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    // Allow the streak to "hold" if today has no session yet but yesterday did.
    if (!days.contains(cursor.millisecondsSinceEpoch)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor.millisecondsSinceEpoch)) return 0;
    }
    var count = 0;
    while (days.contains(cursor.millisecondsSinceEpoch)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  @override
  List<WidgetOptionSpec> optionSchema(WidgetSizeBucket size) => [
        const WidgetOptionSpec.enumChoice('quickPattern', 'Паттерн', {
          'box': 'Бокс (4-4-4-4)',
          '4-7-8': '4-7-8',
          'coherence': 'Когерентность (5-5)',
        }, defaultValue: 'box'),
        if (size == WidgetSizeBucket.small)
          const WidgetOptionSpec.enumChoice('metric', 'Показатель', {
            'streak': 'Дзен-стрик',
            'minutes': 'Минуты недели',
          }, defaultValue: 'streak'),
      ];

  @override
  BreathingWidgetData sampleData(WidgetSizeBucket size) => BreathingWidgetData(
        zenStreakDays: 12,
        minutesThisWeek: 47,
        totalSessions: 38,
        lastSessionAt: DateTime.now().subtract(const Duration(hours: 20)),
        quickPatternId: 'box',
      );

  @override
  Widget render(
      WidgetRenderContext ctx, WidgetConfig cfg, BreathingWidgetData data) {
    return switch (cfg.sizeBucket) {
      WidgetSizeBucket.small =>
        _SmallBreathingWidget(ctx: ctx, cfg: cfg, data: data),
      WidgetSizeBucket.medium =>
        _MediumBreathingWidget(ctx: ctx, data: data),
      WidgetSizeBucket.large => _LargeBreathingWidget(ctx: ctx, data: data),
    };
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _patternLabel(String id) => switch (id) {
      'box' => 'Бокс',
      '4-7-8' => '4-7-8',
      'coherence' => 'Когерентность',
      _ => 'Бокс',
    };

/// Orb glow colour — branded teal, optionally tinted toward [warning] when the
/// streak is at risk, or the theme accent if the user picked "inherit accent".
Color _orbColor(BreathingWidgetData data, WidgetRenderContext ctx) {
  if (data.streakAtRisk) return ctx.colors.warning;
  final style = ctx.config.contentOptions['orbStyle'] as String?;
  return style == 'accent' ? ctx.accent : _kRimTeal;
}

// ── Small (160×160) ───────────────────────────────────────────────────────────

class _SmallBreathingWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final WidgetConfig cfg;
  final BreathingWidgetData data;

  const _SmallBreathingWidget(
      {required this.ctx, required this.cfg, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    final metric = cfg.contentOptions['metric'] as String? ?? 'streak';
    final orbColor = _orbColor(data, ctx);
    final showMinutes = metric == 'minutes';
    final value = showMinutes ? '${data.minutesThisWeek}' : '${data.zenStreakDays}';
    final label = showMinutes ? 'мин/нед' : 'дней';

    return Container(
      width: 160,
      height: 160,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: CustomPaint(
              painter: _OrbPainter(color: orbColor),
              child: Center(
                child: data.neverPractised
                    ? Icon(Icons.air, color: orbColor, size: 26)
                    : Text(
                        value,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.neverPractised ? 'Подыши' : label,
            style: TextStyle(color: c.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Medium (320×160) ──────────────────────────────────────────────────────────

class _MediumBreathingWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final BreathingWidgetData data;

  const _MediumBreathingWidget({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    final orbColor = _orbColor(data, ctx);
    return Container(
      width: 320,
      height: 160,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CustomPaint(
              painter: _OrbPainter(color: orbColor),
              child: Center(
                child: Icon(Icons.air, color: orbColor, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (data.neverPractised)
                  Text(
                    'Начни первую\nсессию',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  )
                else ...[
                  _StatLine(
                    c: c,
                    value: '${data.zenStreakDays}',
                    label: 'дзен-стрик',
                    color: data.streakAtRisk ? c.warning : orbColor,
                  ),
                  const SizedBox(height: 8),
                  _StatLine(
                    c: c,
                    value: '${data.minutesThisWeek}',
                    label: 'мин на неделе',
                    color: c.textPrimary,
                  ),
                ],
                const SizedBox(height: 10),
                _PatternChip(c: c, patternId: data.quickPatternId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Large (320×320) ───────────────────────────────────────────────────────────

class _LargeBreathingWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final BreathingWidgetData data;

  const _LargeBreathingWidget({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    final orbColor = _orbColor(data, ctx);
    return Container(
      width: 320,
      height: 320,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        children: [
          // Hero orb
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _OrbPainter(color: orbColor, strokeWidth: 4),
              child: Center(
                child: data.neverPractised
                    ? Icon(Icons.air, color: orbColor, size: 38)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${data.zenStreakDays}',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'дзен-стрик',
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (data.streakAtRisk)
            Text(
              'Сохрани стрик',
              style: TextStyle(
                  color: c.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            )
          else if (data.neverPractised)
            Text(
              'Начни первую сессию',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          const Spacer(),
          // Quick pattern row (visual; tap-to-start lands on the breathing
          // screen — per-pattern deep-link is a future enhancement).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(child: _PatternButton(label: 'Бокс')),
              SizedBox(width: 8),
              Expanded(child: _PatternButton(label: '4-7-8')),
              SizedBox(width: 8),
              Expanded(child: _PatternButton(label: 'Когерент.')),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: c.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(c: c, value: '${data.zenStreakDays}', label: 'стрик'),
              _MiniStat(
                  c: c, value: '${data.minutesThisWeek}', label: 'мин/нед'),
              _MiniStat(
                  c: c, value: '${data.totalSessions}', label: 'всего'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _StatLine extends StatelessWidget {
  final SieColors c;
  final String value;
  final String label;
  final Color color;

  const _StatLine({
    required this.c,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _PatternChip extends StatelessWidget {
  final SieColors c;
  final String patternId;

  const _PatternChip({required this.c, required this.patternId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 14, color: _kRimTeal),
          const SizedBox(width: 4),
          Text(
            'Подышать · ${_patternLabel(patternId)}',
            style: TextStyle(color: c.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PatternButton extends StatelessWidget {
  final String label;
  const _PatternButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _kRimTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kRimTeal.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
              color: _kRimTealLight,
              fontSize: 11,
              fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final SieColors c;
  final String value;
  final String label;

  const _MiniStat(
      {required this.c, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 10)),
      ],
    );
  }
}

// ── Orb Painter (static frame of the session orb) ─────────────────────────────

class _OrbPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _OrbPainter({required this.color, this.strokeWidth = 3.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Soft inner glow.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.06),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, glow);

    // Bright rim sweep.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.7),
          _kRimTealLight,
          color,
          _kRimTealLight,
          color.withValues(alpha: 0.7),
        ],
        stops: const [0.0, 0.28, 0.5, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, rim);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
