import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../local/app_database.dart';
import '../../theme/sie_colors.dart';
import '../module_widget_provider.dart';
import '../widget_config.dart';
import '../widget_size_bucket.dart';
import '../widget_theme_bridge.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

enum FocusWidgetPhase { idle, work, breakTime }

class FocusWidgetData extends WidgetData {
  final FocusWidgetPhase phase;
  final int secondsRemaining;
  final int totalSecs;
  final int completedToday;
  final bool isRunning;
  final String? taskTitle;
  final int workMinutes;
  final int breakMinutes;

  const FocusWidgetData({
    required this.phase,
    required this.secondsRemaining,
    required this.totalSecs,
    required this.completedToday,
    required this.isRunning,
    this.taskTitle,
    this.workMinutes = 25,
    this.breakMinutes = 5,
  });

  double get progress => totalSecs > 0
      ? (1.0 - secondsRemaining / totalSecs).clamp(0.0, 1.0)
      : 0.0;

  String get formattedTime {
    final m = secondsRemaining ~/ 60;
    final s = secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  String get signature =>
      '${phase.name}:$secondsRemaining:$totalSecs:$completedToday:$isRunning';
}

// ── Provider ──────────────────────────────────────────────────────────────────

class FocusWidgetProvider extends ModuleWidgetProvider<FocusWidgetData> {
  @override
  String get moduleId => 'focus';
  @override
  String get displayName => 'Фокус';
  @override
  IconData get glyph => Icons.timer_outlined;
  @override
  String get androidProviderClass => 'FocusWidgetProvider';
  @override
  List<WidgetSizeBucket> get supportedSizes =>
      const [WidgetSizeBucket.small, WidgetSizeBucket.medium, WidgetSizeBucket.large];

  @override
  Future<FocusWidgetData> loadData(AppDatabase db, WidgetConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    final phaseStr = prefs.getString('focus_phase'); // 'work' | 'break' | null
    final FocusWidgetPhase phase;
    if (phaseStr == 'work') {
      phase = FocusWidgetPhase.work;
    } else if (phaseStr == 'break') {
      phase = FocusWidgetPhase.breakTime;
    } else {
      phase = FocusWidgetPhase.idle;
    }

    final workMinutes = prefs.getInt('focus_work_minutes') ?? 25;
    final breakMinutes = prefs.getInt('focus_break_minutes') ?? 5;
    final defaultSecs = phase == FocusWidgetPhase.breakTime
        ? breakMinutes * 60
        : workMinutes * 60;
    final totalSecs = prefs.getInt('focus_total_duration_secs') ?? defaultSecs;
    final completedToday = prefs.getInt('focus_completed_sessions') ?? 0;
    final isRunning = prefs.getBool('focus_is_running') ?? false;
    final taskTitle = prefs.getString('focus_task_title');

    // Compute the live remaining time from the wall clock when the session is
    // running (the persisted `focus_secs_remaining` is only a snapshot taken at
    // the last save). Mirrors FocusTimerNotifier's restore logic so each widget
    // refresh shows the correct time rather than a stale value.
    var secsRemaining = prefs.getInt('focus_secs_remaining') ?? defaultSecs;
    final phaseStartMs = prefs.getInt('focus_phase_start_ms');
    if (isRunning && phaseStartMs != null) {
      final elapsed = (DateTime.now().millisecondsSinceEpoch - phaseStartMs) ~/
          1000;
      secsRemaining = (totalSecs - elapsed).clamp(0, totalSecs);
    }

    return FocusWidgetData(
      phase: phase,
      secondsRemaining: secsRemaining,
      totalSecs: totalSecs,
      completedToday: completedToday,
      isRunning: isRunning,
      taskTitle: taskTitle,
      workMinutes: workMinutes,
      breakMinutes: breakMinutes,
    );
  }

  @override
  FocusWidgetData sampleData(WidgetSizeBucket size) => const FocusWidgetData(
        phase: FocusWidgetPhase.work,
        secondsRemaining: 18 * 60 + 42,
        totalSecs: 25 * 60,
        completedToday: 2,
        isRunning: true,
        workMinutes: 25,
        breakMinutes: 5,
      );

  @override
  List<WidgetTapZone> tapZones(WidgetConfig cfg, FocusWidgetData data) =>
      const [];

  @override
  Widget render(
      WidgetRenderContext ctx, WidgetConfig cfg, FocusWidgetData data) {
    return switch (cfg.sizeBucket) {
      WidgetSizeBucket.small => _SmallFocusWidget(ctx: ctx, data: data),
      WidgetSizeBucket.medium => _MediumFocusWidget(ctx: ctx, data: data),
      WidgetSizeBucket.large => _LargeFocusWidget(ctx: ctx, data: data),
    };
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _ringColor(FocusWidgetData data, WidgetRenderContext ctx) =>
    switch (data.phase) {
      FocusWidgetPhase.idle => ctx.colors.iconMuted,
      FocusWidgetPhase.work => ctx.accent,
      FocusWidgetPhase.breakTime => ctx.colors.accentSecondary,
    };

String _phaseLabel(FocusWidgetPhase phase) => switch (phase) {
      FocusWidgetPhase.idle => 'ГОТОВ',
      FocusWidgetPhase.work => 'ФОКУС',
      FocusWidgetPhase.breakTime => 'ПЕРЕРЫВ',
    };

// ── Small (160×160) ───────────────────────────────────────────────────────────

class _SmallFocusWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final FocusWidgetData data;

  const _SmallFocusWidget({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    final ringC = _ringColor(data, ctx);
    return Container(
      width: 160,
      height: 160,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CustomPaint(
              painter: _FocusRingPainter(
                progress: data.phase == FocusWidgetPhase.idle ? 0 : data.progress,
                ringColor: ringC,
                trackColor: c.border,
              ),
              child: Center(
                child: data.phase == FocusWidgetPhase.idle
                    ? Icon(Icons.timer_outlined, color: c.iconMuted, size: 28)
                    : Text(
                        data.formattedTime,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _phaseLabel(data.phase),
            style: TextStyle(
              color: ringC,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Medium (320×160) ──────────────────────────────────────────────────────────

class _MediumFocusWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final FocusWidgetData data;

  const _MediumFocusWidget({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    final ringC = _ringColor(data, ctx);
    return Container(
      width: 320,
      height: 160,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _FocusRingPainter(
                progress: data.phase == FocusWidgetPhase.idle ? 0 : data.progress,
                ringColor: ringC,
                trackColor: c.border,
              ),
              child: Center(
                child: data.phase == FocusWidgetPhase.idle
                    ? Icon(Icons.timer_outlined, color: c.iconMuted, size: 32)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data.formattedTime,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ФОКУС-ТАЙМЕР',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _phaseLabel(data.phase),
                  style: TextStyle(
                    color: ringC,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (data.phase == FocusWidgetPhase.idle)
                  Text(
                    '${data.workMinutes} мин / ${data.breakMinutes} мин',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  )
                else ...[
                  if (data.taskTitle != null && data.taskTitle!.isNotEmpty)
                    Text(
                      data.taskTitle!,
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 12, color: c.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${data.completedToday} сегодня',
                        style: TextStyle(color: c.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Large (320×320) ───────────────────────────────────────────────────────────

class _LargeFocusWidget extends StatelessWidget {
  final WidgetRenderContext ctx;
  final FocusWidgetData data;

  const _LargeFocusWidget({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = ctx.colors;
    final ringC = _ringColor(data, ctx);
    return Container(
      width: 320,
      height: 320,
      decoration: ctx.surfaceDecoration,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ФОКУС-ТАЙМЕР',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              if (data.completedToday > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ctx.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${data.completedToday}×',
                    style: TextStyle(
                        color: ctx.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Central ring
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _FocusRingPainter(
                  progress: data.phase == FocusWidgetPhase.idle
                      ? 0
                      : data.progress,
                  ringColor: ringC,
                  trackColor: c.border,
                  strokeWidth: 7,
                ),
                child: Center(
                  child: data.phase == FocusWidgetPhase.idle
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined,
                                color: c.iconMuted, size: 36),
                            const SizedBox(height: 4),
                            Text(
                              'Нажмите',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 12),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.formattedTime,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            Text(
                              _phaseLabel(data.phase),
                              style: TextStyle(
                                color: ringC,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Session info divider
          Container(height: 1, color: c.border),
          const SizedBox(height: 14),
          // Settings / task row
          if (data.phase == FocusWidgetPhase.idle) ...[
            Row(
              children: [
                _InfoChip(
                    c: c,
                    icon: Icons.work_outline,
                    label: '${data.workMinutes} мин'),
                const SizedBox(width: 8),
                _InfoChip(
                    c: c,
                    icon: Icons.coffee_outlined,
                    label: '${data.breakMinutes} мин'),
              ],
            ),
          ] else ...[
            if (data.taskTitle != null && data.taskTitle!.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 13, color: c.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.taskTitle!,
                      style:
                          TextStyle(color: c.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                _InfoChip(
                    c: c,
                    icon: Icons.work_outline,
                    label: '${data.workMinutes} мин'),
                const SizedBox(width: 8),
                _InfoChip(
                    c: c,
                    icon: Icons.check_circle_outline,
                    label: '${data.completedToday} сессий'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final SieColors c;
  final IconData icon;
  final String label;

  const _InfoChip({required this.c, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ── Ring Painter ──────────────────────────────────────────────────────────────

class _FocusRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  const _FocusRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    this.strokeWidth = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
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

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
