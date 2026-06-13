import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import '../widgets/sparkline.dart';

String _fmt(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class MilestoneMetricScreen extends ConsumerWidget {
  const MilestoneMetricScreen({
    super.key,
    required this.milestone,
    required this.goalId,
  });

  final Milestone milestone;
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = ref.watch(sieColorsProvider);
    final logsAsync = ref.watch(milestoneLogsProvider(milestone.id));

    // Always read latest milestone from provider state.
    final ms = ref
            .watch(planningProvider)
            .valueOrNull
            ?.goals
            .expand((g) => g.milestones)
            .where((m) => m.id == milestone.id)
            .firstOrNull ??
        milestone;

    final progress = metricProgress(ms);
    final unit = ms.unit ?? '';

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: sc.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(ms.name,
              style: TextStyle(color: sc.textPrimary, fontSize: 16)),
        ),
        body: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Text('Ошибка загрузки',
                  style: TextStyle(color: sc.textSecondary))),
          data: (logs) => _Body(
            ms: ms,
            logs: logs,
            sc: sc,
            goalId: goalId,
            progress: progress,
            unit: unit,
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.ms,
    required this.logs,
    required this.sc,
    required this.goalId,
    required this.progress,
    required this.unit,
  });

  final Milestone ms;
  final List<MilestoneLog> logs;
  final SieColors sc;
  final String goalId;
  final double progress;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = logs.map((l) => l.value).toList();
    final currentDisplay = ms.currentValue != null
        ? '${_fmt(ms.currentValue!)}${unit.isNotEmpty ? ' $unit' : ''}'
        : '—';
    final targetDisplay = ms.targetValue != null
        ? '${_fmt(ms.targetValue!)}${unit.isNotEmpty ? ' $unit' : ''}'
        : '—';
    final pct = (progress * 100).round();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Current / target summary card.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sc.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatBox(
                      label: 'СЕЙЧАС',
                      value: currentDisplay,
                      color: sc.accent,
                      sc: sc),
                  _StatBox(
                      label: 'ЦЕЛЬ',
                      value: targetDisplay,
                      color: sc.textSecondary,
                      sc: sc),
                  _StatBox(
                      label: 'ПРОГРЕСС',
                      value: '$pct%',
                      color: ms.isCompleted ? sc.success : sc.accent,
                      sc: sc),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar.
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: sc.border,
                  valueColor: AlwaysStoppedAnimation(
                      ms.isCompleted ? sc.success : sc.accent),
                ),
              ),
              if (ms.isCompleted) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: sc.accent, size: 16),
                    const SizedBox(width: 6),
                    Text('Цель достигнута!',
                        style: TextStyle(color: sc.accent, fontSize: 13)),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Full chart (if 2+ data points).
        if (values.length >= 2) ...[
          Text('ДИНАМИКА',
              style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Container(
            height: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sc.border),
            ),
            child: _FullChart(values: values, logs: logs, sc: sc),
          ),
          const SizedBox(height: 20),
        ],

        // History list header + "Внести замер" button.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ИСТОРИЯ ЗАМЕРОВ',
                style: TextStyle(
                    color: sc.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.2)),
            if (!ms.isCompleted)
              GestureDetector(
                onTap: () => _showLogSheet(context, ref),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sc.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 14, color: sc.accent),
                      const SizedBox(width: 4),
                      Text('ЗАМЕР',
                          style: TextStyle(
                              color: sc.accent,
                              fontSize: 11,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (logs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Нет замеров',
                  style: TextStyle(color: sc.textSecondary, fontSize: 13)),
            ),
          )
        else
          ...logs.reversed.map((log) => _LogTile(
                log: log,
                ms: ms,
                goalId: goalId,
                sc: sc,
              )),

        const SizedBox(height: 40),
      ],
    );
  }

  void _showLogSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _LogMeasurementSheet(milestone: ms, goalId: goalId, sc: sc),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.sc});
  final String label;
  final String value;
  final Color color;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style:
                TextStyle(color: sc.textSecondary, fontSize: 9, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _FullChart extends StatelessWidget {
  const _FullChart(
      {required this.values, required this.logs, required this.sc});
  final List<double> values;
  final List<MilestoneLog> logs;
  final SieColors sc;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FullChartPainter(values: values, logs: logs, sc: sc),
      child: const SizedBox.expand(),
    );
  }
}

class _FullChartPainter extends CustomPainter {
  _FullChartPainter(
      {required this.values, required this.logs, required this.sc});
  final List<double> values;
  final List<MilestoneLog> logs;
  final SieColors sc;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = maxV - minV;

    final linePaint = Paint()
      ..color = sc.accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = sc.accent
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = sc.border
      ..strokeWidth = 0.5;

    // Draw 3 horizontal grid lines.
    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw line.
    final path = Path();
    final pts = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = range == 0
          ? size.height / 2
          : size.height - ((values[i] - minV) / range) * (size.height * 0.85) -
              (size.height * 0.075);
      pts.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Fill area under line.
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..color = sc.accent.withOpacity(0.07)
          ..style = PaintingStyle.fill);

    // Dots.
    for (final pt in pts) {
      canvas.drawCircle(pt, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_FullChartPainter old) => old.values != values;
}

class _LogTile extends ConsumerWidget {
  const _LogTile(
      {required this.log,
      required this.ms,
      required this.goalId,
      required this.sc});
  final MilestoneLog log;
  final Milestone ms;
  final String goalId;
  final SieColors sc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ms.unit ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: sc.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_fmt(log.value)}${unit.isNotEmpty ? ' $unit' : ''}',
              style: TextStyle(color: sc.textPrimary, fontSize: 15),
            ),
          ),
          Text(
            _fmtDate(log.recordedAt),
            style: TextStyle(color: sc.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: sc.surface,
                  title: Text('Удалить замер?',
                      style: TextStyle(color: sc.textPrimary)),
                  content: Text(
                      'Замер ${_fmt(log.value)}${unit.isNotEmpty ? ' $unit' : ''} будет удалён.',
                      style: TextStyle(color: sc.textSecondary)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('ОТМЕНА',
                            style: TextStyle(color: sc.textSecondary))),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('УДАЛИТЬ',
                            style: TextStyle(color: sc.danger))),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(planningProvider.notifier).deleteMilestoneLog(
                    log.id, ms.id, goalId);
              }
            },
            child: Icon(Icons.close, size: 14, color: sc.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Log Measurement Sheet ────────────────────────────────────────────────────

class _LogMeasurementSheet extends ConsumerStatefulWidget {
  const _LogMeasurementSheet(
      {required this.milestone, required this.goalId, required this.sc});
  final Milestone milestone;
  final String goalId;
  final SieColors sc;

  @override
  ConsumerState<_LogMeasurementSheet> createState() =>
      _LogMeasurementSheetState();
}

class _LogMeasurementSheetState
    extends ConsumerState<_LogMeasurementSheet> {
  late final TextEditingController _ctrl;
  double? _parsed;

  @override
  void initState() {
    super.initState();
    final initial = widget.milestone.currentValue;
    _ctrl = TextEditingController(
        text: initial != null ? _fmt(initial) : '');
    _parsed = initial;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _applyDelta(double delta) {
    final current = _parsed ?? widget.milestone.currentValue ?? 0;
    final next = (current + delta);
    setState(() {
      _parsed = next;
      _ctrl.text = _fmt(next);
      _ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _ctrl.text.length));
    });
  }

  void _onChanged(String s) {
    setState(() => _parsed = double.tryParse(s.replaceAll(',', '.')));
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.sc;
    final ms = widget.milestone;
    final unit = ms.unit ?? '';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ВНЕСТИ ЗАМЕР',
              style: TextStyle(
                  color: sc.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(ms.name,
              style: TextStyle(
                  color: sc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),

          // Value input row.
          Row(
            children: [
              // ±0.1 step
              _StepBtn(label: '−0.1', sc: sc,
                  onTap: () => _applyDelta(-0.1)),
              const SizedBox(width: 8),
              _StepBtn(label: '−1', sc: sc,
                  onTap: () => _applyDelta(-1)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: sc.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    suffixText: unit,
                    suffixStyle:
                        TextStyle(color: sc.textSecondary, fontSize: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: sc.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: sc.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: sc.accent)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  onChanged: _onChanged,
                ),
              ),
              const SizedBox(width: 12),
              _StepBtn(label: '+1', sc: sc,
                  onTap: () => _applyDelta(1)),
              const SizedBox(width: 8),
              _StepBtn(label: '+0.1', sc: sc,
                  onTap: () => _applyDelta(0.1)),
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _parsed == null
                  ? null
                  : () {
                      ref
                          .read(planningProvider.notifier)
                          .addMilestoneLog(ms.id, widget.goalId, _parsed!);
                      SieHaptics.success();
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: sc.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('СОХРАНИТЬ',
                  style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn(
      {required this.label, required this.sc, required this.onTap});
  final String label;
  final SieColors sc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: sc.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sc.border),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: sc.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
