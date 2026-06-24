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
  /// 'breathing' = Breathing exercise module; 'meditation' = Meditation module.
  final String module;
  final int zenStreakDays;    // meaningful only for meditation mode
  final int minutesThisWeek;
  final int totalSessions;
  final DateTime? lastSessionAt;
  final String quickPatternId;

  const BreathingWidgetData({
    required this.module,
    required this.zenStreakDays,
    required this.minutesThisWeek,
    required this.totalSessions,
    required this.lastSessionAt,
    required this.quickPatternId,
  });

  bool get neverPractised => totalSessions == 0;

  bool get isBreathingModule => module == 'breathing';

  /// Streak at-risk: relevant only in meditation mode.
  bool get streakAtRisk {
    if (isBreathingModule) return false;
    if (lastSessionAt == null || zenStreakDays == 0) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(
        lastSessionAt!.year, lastSessionAt!.month, lastSessionAt!.day);
    return last.isBefore(today);
  }

  @override
  String get signature =>
      '$module:$zenStreakDays:$minutesThisWeek:$totalSessions:'
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
  Map<WidgetSizeBucket, String> get androidProviderClasses => const {
        WidgetSizeBucket.small: 'BreathingSmallWidgetProvider',
        WidgetSizeBucket.medium: 'BreathingMediumWidgetProvider',
        WidgetSizeBucket.large: 'BreathingLargeWidgetProvider',
      };
  @override
  List<WidgetSizeBucket> get supportedSizes => const [
        WidgetSizeBucket.small,
        WidgetSizeBucket.medium,
        WidgetSizeBucket.large,
      ];

  @override
  String resolveDeepLinkHost(WidgetConfig cfg) {
    final mod = cfg.contentOptions['module'] as String? ?? 'breathing';
    return mod == 'meditation' ? 'meditation' : 'breathing';
  }

  @override
  Future<BreathingWidgetData> loadData(AppDatabase db, WidgetConfig cfg) async {
    final module = cfg.contentOptions['module'] as String? ?? 'breathing';
    final quickPattern =
        cfg.contentOptions['quickPattern'] as String? ?? 'box';

    if (module == 'meditation') {
      return _loadMeditationData(db, quickPattern);
    } else {
      return _loadBreathingData(db, quickPattern);
    }
  }

  Future<BreathingWidgetData> _loadBreathingData(
      AppDatabase db, String quickPattern) async {
    final sessions = await db.breathingSessionsForWidget();

    var weekSecs = 0;
    final now = DateTime.now();
    final weekStartMs = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    for (final s in sessions) {
      if (s.completedAtMs >= weekStartMs) weekSecs += s.durationSeconds;
    }

    DateTime? lastAt;
    if (sessions.isNotEmpty) {
      final stamps = sessions.map((s) => s.completedAtMs).toList()..sort();
      lastAt = DateTime.fromMillisecondsSinceEpoch(stamps.last);
    }

    return BreathingWidgetData(
      module: 'breathing',
      zenStreakDays: 0,
      minutesThisWeek: weekSecs ~/ 60,
      totalSessions: sessions.length,
      lastSessionAt: lastAt,
      quickPatternId: quickPattern,
    );
  }

  Future<BreathingWidgetData> _loadMeditationData(
      AppDatabase db, String quickPattern) async {
    final sessions = await db.meditationSessionsForWidget();

    var weekSecs = 0;
    final now = DateTime.now();
    final weekStartMs = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    final stamps = <int>[];
    for (final s in sessions) {
      stamps.add(s.completedAtMs);
      if (s.completedAtMs >= weekStartMs) weekSecs += s.durationSeconds;
    }

    DateTime? lastAt;
    if (stamps.isNotEmpty) {
      final sorted = List<int>.from(stamps)..sort();
      lastAt = DateTime.fromMillisecondsSinceEpoch(sorted.last);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final streak =
        prefs.getInt(kWidgetZenStreakKey) ?? _streakFromStamps(stamps);

    return BreathingWidgetData(
      module: 'meditation',
      zenStreakDays: streak,
      minutesThisWeek: weekSecs ~/ 60,
      totalSessions: sessions.length,
      lastSessionAt: lastAt,
      quickPatternId: quickPattern,
    );
  }

  int _streakFromStamps(List<int> stampsMs) {
    if (stampsMs.isEmpty) return 0;
    final days = <int>{};
    for (final ms in stampsMs) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      days.add(DateTime(d.year, d.month, d.day).millisecondsSinceEpoch);
    }
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
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
        const WidgetOptionSpec.enumChoice('module', 'Открывать модуль', {
          'breathing': 'Дыхание',
          'meditation': 'Медитация с дыханием',
        }, defaultValue: 'breathing'),
        const WidgetOptionSpec.enumChoice('quickPattern', 'Паттерн', {
          'box': 'Бокс (4-4-4-4)',
          '4-7-8': '4-7-8',
          'coherence': 'Когерентность (5-5)',
        }, defaultValue: 'box'),
        if (size == WidgetSizeBucket.small)
          const WidgetOptionSpec.enumChoice('metric', 'Показатель', {
            'sessions': 'Сессий всего',
            'minutes': 'Минуты недели',
            'streak': 'Дзен-стрик (медитация)',
          }, defaultValue: 'sessions'),
      ];

  @override
  BreathingWidgetData sampleData(WidgetSizeBucket size) => BreathingWidgetData(
        module: 'breathing',
        zenStreakDays: 0,
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
    final orbColor = _orbColor(data, ctx);
    final metric = cfg.contentOptions['metric'] as String? ?? 'sessions';

    String value;
    String label;
    if (data.isBreathingModule) {
      // streak option is meaningless in breathing mode — fall back to sessions
      if (metric == 'minutes') {
        value = '${data.minutesThisWeek}';
        label = 'мин/нед';
      } else {
        value = '${data.totalSessions}';
        label = 'сессий';
      }
    } else {
      if (metric == 'minutes') {
        value = '${data.minutesThisWeek}';
        label = 'мин/нед';
      } else {
        value = '${data.zenStreakDays}';
        label = 'дней';
      }
    }

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
            child: data.isBreathingModule
                ? _BreathingModeColumn(c: c, data: data, orbColor: orbColor)
                : _MeditationModeColumn(c: c, data: data, orbColor: orbColor),
          ),
        ],
      ),
    );
  }
}

class _BreathingModeColumn extends StatelessWidget {
  final SieColors c;
  final BreathingWidgetData data;
  final Color orbColor;

  const _BreathingModeColumn(
      {required this.c, required this.data, required this.orbColor});

  @override
  Widget build(BuildContext context) {
    return Column(
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
            value: '${data.totalSessions}',
            label: 'сессий',
            color: orbColor,
          ),
          const SizedBox(height: 6),
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
    );
  }
}

class _MeditationModeColumn extends StatelessWidget {
  final SieColors c;
  final BreathingWidgetData data;
  final Color orbColor;

  const _MeditationModeColumn(
      {required this.c, required this.data, required this.orbColor});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          // Hero orb — content depends on module mode
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _OrbPainter(color: orbColor, strokeWidth: 4),
              child: Center(
                child: data.neverPractised
                    ? Icon(Icons.air, color: orbColor, size: 38)
                    : data.isBreathingModule
                        ? _BreathingOrbContent(c: c, data: data)
                        : _MeditationOrbContent(c: c, data: data),
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
          data.isBreathingModule
              ? _BreathingMiniStats(c: c, data: data)
              : _MeditationMiniStats(c: c, data: data),
        ],
      ),
    );
  }
}

class _BreathingOrbContent extends StatelessWidget {
  final SieColors c;
  final BreathingWidgetData data;
  const _BreathingOrbContent({required this.c, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${data.totalSessions}',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'сессий',
          style: TextStyle(color: c.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _MeditationOrbContent extends StatelessWidget {
  final SieColors c;
  final BreathingWidgetData data;
  const _MeditationOrbContent({required this.c, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          style: TextStyle(color: c.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _BreathingMiniStats extends StatelessWidget {
  final SieColors c;
  final BreathingWidgetData data;
  const _BreathingMiniStats({required this.c, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _MiniStat(c: c, value: '${data.totalSessions}', label: 'сессий'),
        _MiniStat(c: c, value: '${data.minutesThisWeek}', label: 'мин/нед'),
        _MiniStat(
            c: c,
            value: _patternLabel(data.quickPatternId),
            label: 'паттерн'),
      ],
    );
  }
}

class _MeditationMiniStats extends StatelessWidget {
  final SieColors c;
  final BreathingWidgetData data;
  const _MeditationMiniStats({required this.c, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _MiniStat(c: c, value: '${data.zenStreakDays}', label: 'стрик'),
        _MiniStat(c: c, value: '${data.minutesThisWeek}', label: 'мин/нед'),
        _MiniStat(c: c, value: '${data.totalSessions}', label: 'всего'),
      ],
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
