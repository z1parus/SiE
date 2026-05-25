import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

const _kCyan = Color(0xFF00E5FF);
const _kPurple = Color(0xFF7000FF);

class ProgressAnalyticsScreen extends ConsumerWidget {
  const ProgressAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return GlassPage(
      background: SieSpaceBackground(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: analyticsAsync.when(
                  data: (data) => _AnalyticsBody(data: data),
                  loading: () => const _LoadingState(),
                  error: (e, _) => _ErrorState(error: e),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SieGlassCard(
            padding: EdgeInsets.zero,
            width: 40,
            height: 40,
            onTap: onBack,
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: _kCyan,
              size: 18,
            ),
          ),
          Expanded(
            child: Text(
              'PROGRESS HUB',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ── Loading / Error ───────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: _kCyan,
        strokeWidth: 1.5,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'ERROR: $error',
        style: const TextStyle(color: Colors.redAccent),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Main Body ─────────────────────────────────────────────────

class _AnalyticsBody extends StatelessWidget {
  final AnalyticsData data;
  const _AnalyticsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _StatsRow(data: data),
        const SizedBox(height: 28),
        _SectionLabel(label: 'ACTIVITY MATRIX'),
        const SizedBox(height: 12),
        _HeatMap(heatMap: data.heatMap),
        const SizedBox(height: 28),
        _SectionLabel(label: 'XP GROWTH — 7 DAYS'),
        const SizedBox(height: 12),
        _XpLineChart(points: data.xpHistory),
        const SizedBox(height: 28),
        _SectionLabel(label: 'FOCUS TIME — 7 DAYS'),
        const SizedBox(height: 12),
        _FocusBarChart(points: data.focusByDay),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 12,
          decoration: BoxDecoration(
            color: _kCyan,
            boxShadow: [
              BoxShadow(
                color: _kCyan.withValues(alpha: 0.7),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 2,
                color: _kCyan.withValues(alpha: 0.9),
              ),
        ),
      ],
    );
  }
}

// ── Stats Cards ───────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final AnalyticsData data;
  const _StatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final focusH = data.totalFocusMinutes ~/ 60;
    final focusM = data.totalFocusMinutes % 60;
    final focusLabel = focusH > 0 ? '${focusH}h ${focusM}m' : '${focusM}m';
    final completionPct = (data.habitCompletionRate * 100).round();

    return Row(
      children: [
        Expanded(
          child: RepaintBoundary(
            child: _StatCard(
              icon: Icons.timer_outlined,
              value: focusLabel,
              label: 'TOTAL\nFOCUS',
              color: _kCyan,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RepaintBoundary(
            child: _StatCard(
              icon: Icons.check_circle_outline,
              value: '$completionPct%',
              label: 'HABITS\n30 DAYS',
              color: _kPurple,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RepaintBoundary(
            child: _StatCard(
              icon: Icons.local_fire_department_outlined,
              value: '${data.currentStreak}',
              label: 'DAY\nSTREAK',
              color: const Color(0xFFFFB347),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SieGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              height: 1,
              shadows: [
                Shadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: SieTheme.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Heat Map ──────────────────────────────────────────────────
// 13 columns (weeks) × 7 rows (Mon–Sun), most recent day = bottom-right

class _HeatMap extends StatelessWidget {
  final Map<DateTime, int> heatMap;
  const _HeatMap({required this.heatMap});

  static Color _cellColor(int count) {
    if (count <= 0) return Colors.white.withValues(alpha: 0.05);
    if (count == 1) return _kCyan.withValues(alpha: 0.22);
    if (count <= 3) return _kCyan.withValues(alpha: 0.45);
    if (count <= 5) return _kCyan.withValues(alpha: 0.70);
    return _kCyan;
  }

  static BoxShadow? _cellGlow(int count) {
    if (count <= 3) return null;
    final alpha = count <= 5 ? 0.4 : 0.8;
    return BoxShadow(
      color: _kCyan.withValues(alpha: alpha),
      blurRadius: 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    final daysSinceMonday = (todayNorm.weekday - 1) % 7;
    final gridEnd =
        todayNorm.add(Duration(days: 6 - daysSinceMonday));
    final gridStart = gridEnd.subtract(const Duration(days: 7 * 13 - 1));

    const cols = 13;
    const rows = 7;
    const cellSize = 14.0;
    const gap = 3.0;

    return SieGlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 28),
              ...List.generate(rows, (r) {
                final label = ['M', '', 'W', '', 'F', '', 'S'][r];
                return SizedBox(
                  width: cellSize + gap,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _kCyan.withValues(alpha: 0.5),
                      fontSize: 8,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 12 + rows * (cellSize + gap) - gap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(cols, (col) {
                final firstDayOfCol =
                    gridStart.add(Duration(days: col * 7));
                String monthLabel = '';
                for (var r = 0; r < rows; r++) {
                  final d = firstDayOfCol.add(Duration(days: r));
                  if (d.day == 1) {
                    const months = [
                      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                    ];
                    monthLabel = months[d.month - 1];
                    break;
                  }
                }

                return Column(
                  children: [
                    SizedBox(
                      height: 12,
                      width: cellSize + gap,
                      child: Text(
                        monthLabel,
                        style: TextStyle(
                          color: _kCyan.withValues(alpha: 0.4),
                          fontSize: 7,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ...List.generate(rows, (row) {
                      final d =
                          gridStart.add(Duration(days: col * 7 + row));
                      final isFuture = d.isAfter(todayNorm);
                      final count = isFuture ? -1 : (heatMap[d] ?? 0);
                      final glow =
                          isFuture ? null : _cellGlow(count);

                      return Container(
                        margin: EdgeInsets.only(
                          right: gap,
                          bottom: row < rows - 1 ? gap : 0,
                        ),
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: isFuture
                              ? Colors.transparent
                              : _cellColor(count),
                          border: Border.all(
                            color: isFuture
                                ? Colors.transparent
                                : _kCyan.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: glow != null ? [glow] : null,
                        ),
                      );
                    }),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'LESS',
                style: TextStyle(
                  color: _kCyan.withValues(alpha: 0.45),
                  fontSize: 8,
                ),
              ),
              const SizedBox(width: 4),
              ...[0, 1, 3, 5, 7].map((c) => Container(
                    margin: const EdgeInsets.only(left: 3),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _cellColor(c),
                      border: Border.all(
                        color: _kCyan.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
              const SizedBox(width: 4),
              Text(
                'MORE',
                style: TextStyle(
                  color: _kCyan.withValues(alpha: 0.45),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── XP Line Chart ─────────────────────────────────────────────

class _XpLineChart extends StatelessWidget {
  final List<DayXp> points;
  const _XpLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxY =
        points.fold(0, (m, p) => math.max(m, p.xp)).toDouble();
    final topY = maxY < 100 ? 200.0 : (maxY * 1.25).ceilToDouble();

    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.xp.toDouble());
    }).toList();

    return SieGlassCard(
      height: 184,
      padding: const EdgeInsets.fromLTRB(0, 12, 12, 8),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: topY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: topY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.08),
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: topY / 4,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
                  style: TextStyle(
                    color: _kCyan.withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox();
                  }
                  final d = points[i].date;
                  const days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
                  return Text(
                    days[d.weekday - 1],
                    style: TextStyle(
                      color: _kCyan.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              gradient: const LinearGradient(
                colors: [_kCyan, _kPurple],
              ),
              barWidth: 2,
              shadow: BoxShadow(
                color: _kCyan.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: _kCyan,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _kCyan.withValues(alpha: 0.22),
                    _kPurple.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0B1E30),
              getTooltipItems: (spots) => spots.map((s) {
                return LineTooltipItem(
                  '+${s.y.toInt()} XP',
                  const TextStyle(
                    color: _kCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Focus Bar Chart ───────────────────────────────────────────

class _FocusBarChart extends StatelessWidget {
  final List<DayFocus> points;
  const _FocusBarChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxY =
        points.fold(0, (m, p) => math.max(m, p.minutes)).toDouble();
    final topY = maxY < 30 ? 60.0 : (maxY * 1.3).ceilToDouble();

    final groups = points.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.minutes.toDouble(),
            width: 18,
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                _kPurple.withValues(alpha: 0.7),
                _kCyan,
              ],
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: topY,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ],
      );
    }).toList();

    return SieGlassCard(
      height: 184,
      padding: const EdgeInsets.fromLTRB(0, 12, 12, 8),
      child: BarChart(
        BarChartData(
          maxY: topY,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: topY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.08),
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: topY / 4,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}m',
                  style: TextStyle(
                    color: _kCyan.withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox();
                  }
                  final d = points[i].date;
                  const days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
                  return Text(
                    days[d.weekday - 1],
                    style: TextStyle(
                      color: _kCyan.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0B1E30),
              getTooltipItem: (_, _, rod, _) => BarTooltipItem(
                '${rod.toY.toInt()} min',
                const TextStyle(
                  color: _kCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
