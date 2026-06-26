import 'package:flutter/material.dart';
import '../../local/app_database.dart';
import '../../theme/sie_colors.dart';
import '../module_widget_provider.dart';
import '../widget_config.dart';
import '../widget_option_spec.dart';
import '../widget_size_bucket.dart';
import '../widget_theme_bridge.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class HabitsWidgetData extends WidgetData {
  final List<HabitTile> dueToday;
  final int doneToday;
  final int totalDueToday;

  const HabitsWidgetData({
    required this.dueToday,
    required this.doneToday,
    required this.totalDueToday,
  });

  double get dayProgress =>
      totalDueToday == 0 ? 1.0 : doneToday / totalDueToday;

  @override
  String get signature =>
      '$doneToday/$totalDueToday:${dueToday.map((t) => '${t.id}:${t.done}').join(',')}';
}

class HabitTile {
  final String id;
  final String title;
  final bool done;
  final int streak;
  final String kind;
  final double? value;
  final double? target;

  const HabitTile({
    required this.id,
    required this.title,
    required this.done,
    required this.streak,
    required this.kind,
    this.value,
    this.target,
  });
}

// ── Provider ──────────────────────────────────────────────────────────────────

class HabitsWidgetProvider extends ModuleWidgetProvider<HabitsWidgetData> {
  @override
  String get moduleId => 'habits';
  @override
  String get displayName => 'Привычки';
  @override
  IconData get glyph => Icons.check_circle_outline;
  @override
  Map<WidgetSizeBucket, String> get androidProviderClasses => const {
        WidgetSizeBucket.small: 'HabitsSmallWidgetProvider',
        WidgetSizeBucket.medium: 'HabitsMediumWidgetProvider',
        WidgetSizeBucket.large: 'HabitsLargeWidgetProvider',
      };
  @override
  List<WidgetSizeBucket> get supportedSizes =>
      const [WidgetSizeBucket.small, WidgetSizeBucket.medium, WidgetSizeBucket.large];

  @override
  Future<HabitsWidgetData> loadData(AppDatabase db, WidgetConfig cfg) async {
    final today = _fmt(DateTime.now());
    final habits = await db.habitsForWidget();
    final logs = await db.habitLogsForDate(today);
    final logSet = {for (final l in logs) l.habitId};

    final dueToday = <HabitTile>[];
    for (final h in habits) {
      if (!_isDueToday(h)) continue;
      final done = logSet.contains(h.id);
      dueToday.add(HabitTile(
        id: h.id,
        title: h.title,
        done: done,
        streak: 0, // simplified for now
        kind: h.kind,
      ));
    }

    final maxItems = cfg.contentOptions['maxItems'] as int? ?? 4;
    final hideCompleted = cfg.contentOptions['hideCompleted'] as bool? ?? false;

    var tiles = hideCompleted
        ? dueToday.where((t) => !t.done).toList()
        : dueToday;
    if (tiles.length > maxItems) tiles = tiles.sublist(0, maxItems);

    return HabitsWidgetData(
      dueToday: tiles,
      doneToday: dueToday.where((t) => t.done).length,
      totalDueToday: dueToday.length,
    );
  }

  bool _isDueToday(LocalHabit h) {
    final now = DateTime.now();
    final schedule = h.schedule;
    if (schedule == 'daily') return true;
    if (schedule == 'weekdays') {
      final weekday = now.weekday; // 1=Mon..7=Sun
      return weekday <= 5;
    }
    return true; // simplified
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  HabitsWidgetData sampleData(WidgetSizeBucket size) => const HabitsWidgetData(
    dueToday: [
      HabitTile(id: '1', title: 'Медитация', done: true, streak: 7, kind: 'binary'),
      HabitTile(id: '2', title: 'Зарядка', done: false, streak: 3, kind: 'binary'),
      HabitTile(id: '3', title: 'Чтение', done: false, streak: 12, kind: 'binary'),
      HabitTile(id: '4', title: 'Вода 2л', done: true, streak: 5, kind: 'count'),
    ],
    doneToday: 2,
    totalDueToday: 4,
  );

  @override
  List<WidgetOptionSpec> optionSchema(WidgetSizeBucket size) => [
    const WidgetOptionSpec.enumChoice('filter', 'Фильтр', {
      'all': 'Все на сегодня',
      'pinned': 'Только закреплённые',
    }),
    WidgetOptionSpec.number('maxItems', 'Макс. строк',
        min: 2,
        max: size == WidgetSizeBucket.large ? 7 : 4,
        defaultValue: size == WidgetSizeBucket.large ? 6 : 4),
    const WidgetOptionSpec.toggle('showStreaks', 'Показывать стрики'),
    const WidgetOptionSpec.toggle('hideCompleted', 'Скрывать выполненные'),
  ];

  @override
  List<WidgetTapZone> tapZones(WidgetConfig cfg, HabitsWidgetData data) {
    // Small widget is a single ring → no per-row zones (whole-widget tap only).
    if (cfg.sizeBucket == WidgetSizeBucket.small) return const [];
    return data.dueToday
        .map((t) => WidgetTapZone(
              actionPath: 'habits/toggle',
              entityId: t.id,
              active: t.done,
            ))
        .toList();
  }

  @override
  Widget render(
      WidgetRenderContext ctx, WidgetConfig cfg, HabitsWidgetData data) {
    return switch (cfg.sizeBucket) {
      WidgetSizeBucket.small =>
        _SmallHabitsWidget(ctx: ctx, data: data),
      WidgetSizeBucket.medium =>
        _MediumHabitsWidget(ctx: ctx, cfg: cfg, data: data),
      WidgetSizeBucket.large =>
        _LargeHabitsWidget(ctx: ctx, cfg: cfg, data: data),
    };
  }
}

// ── Small: progress ring ──────────────────────────────────────────────────────

class _SmallHabitsWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final HabitsWidgetData data;

  const _SmallHabitsWidget({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    return Container(
      width: 160,
      height: 160,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _RingPainter(
                progress: data.dayProgress,
                ringColor: ctx.accent,
                trackColor: c.border,
              ),
              child: Center(
                child: Text(
                  '${data.doneToday}/${data.totalDueToday}',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'привычек',
            style: TextStyle(color: c.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Medium: checklist ─────────────────────────────────────────────────────────

class _MediumHabitsWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final WidgetConfig cfg;
  final HabitsWidgetData data;

  const _MediumHabitsWidget(
      {required this.ctx, required this.cfg, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    final showStreaks = cfg.contentOptions['showStreaks'] as bool? ?? true;
    return Container(
      width: 320,
      height: 160,
      decoration: ctx.surfaceDecoration,
      // Vertical structure is fraction-locked so the native tap-zone overlay
      // (top 36 / rows 110 / bottom 14 of 160) aligns 1:1 under fitXY stretch.
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top region: 36px (header + breathing room).
                SizedBox(
                  height: 36,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _Header(c: c, title: 'Привычки'),
                    ),
                  ),
                ),
                // Checklist region: 110px, rows evenly distributed.
                SizedBox(
                  height: 110,
                  child: data.totalDueToday == 0
                      ? Center(
                          child: Text(
                            'Сегодня отдых',
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 12),
                          ),
                        )
                      : Column(
                          children: data.dueToday
                              .map((t) => Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _HabitRow(
                                        tile: t,
                                        c: c,
                                        accent: ctx.accent,
                                        showStreak: showStreaks,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
                // Bottom region: 14px.
                const SizedBox(height: 14),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(
              painter: _RingPainter(
                progress: data.dayProgress,
                ringColor:
                    data.dayProgress >= 1.0 ? c.success : ctx.accent,
                trackColor: c.border,
              ),
              child: Center(
                child: Text(
                  '${(data.dayProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Large: full checklist ─────────────────────────────────────────────────────

class _LargeHabitsWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final WidgetConfig cfg;
  final HabitsWidgetData data;

  const _LargeHabitsWidget(
      {required this.ctx, required this.cfg, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    final showStreaks = cfg.contentOptions['showStreaks'] as bool? ?? true;
    return Container(
      width: 320,
      height: 320,
      decoration: ctx.surfaceDecoration,
      // Same fraction-locked structure as medium, scaled to 320:
      // top 72 / checklist 220 / bottom 28 — matches the shared overlay.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top region: 72px (padding + header + progress bar).
          SizedBox(
            height: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Expanded(child: _Header(c: c, title: 'Привычки')),
                    Text(
                      '${data.doneToday}/${data.totalDueToday}',
                      style: TextStyle(
                        color: ctx.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: data.dayProgress,
                  backgroundColor: c.border,
                  valueColor: AlwaysStoppedAnimation(
                      data.dayProgress >= 1.0 ? c.success : ctx.accent),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          // Checklist region: 220px, rows evenly distributed.
          SizedBox(
            height: 220,
            child: data.totalDueToday == 0
                ? Center(
                    child: Text(
                      'Сегодня отдых',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  )
                : Column(
                    children: data.dueToday
                        .map((t) => Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _HabitRow(
                                  tile: t,
                                  c: c,
                                  accent: ctx.accent,
                                  showStreak: showStreaks,
                                  large: true,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
          ),
          // Bottom region: 28px.
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final SieColors c;
  final String title;
  const _Header({required this.c, required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      );
}

class _HabitRow extends StatelessWidget {
  final HabitTile tile;
  final SieColors c;
  final Color accent;
  final bool showStreak;
  final bool large;

  const _HabitRow({
    required this.tile,
    required this.c,
    required this.accent,
    required this.showStreak,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: large ? 18 : 14,
            height: large ? 18 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tile.done ? accent : Colors.transparent,
              border: Border.all(
                color: tile.done ? accent : c.border,
                width: 1.5,
              ),
            ),
            child: tile.done
                ? Icon(Icons.check, size: large ? 11 : 9, color: c.background)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tile.title,
              style: TextStyle(
                color: tile.done ? c.textSecondary : c.textPrimary,
                fontSize: large ? 14 : 12,
                decoration:
                    tile.done ? TextDecoration.lineThrough : null,
                decorationColor: c.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showStreak && tile.streak > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\u{1F525}${tile.streak}',
                style:
                    TextStyle(fontSize: large ? 10 : 9, color: accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Ring Painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
