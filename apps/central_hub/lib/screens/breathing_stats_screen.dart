import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'breathing_format.dart';
import 'session_orb_painters.dart';

enum _Period { week, month, year, all }

extension _PeriodX on _Period {
  String get label => switch (this) {
        _Period.week => t.breathingStats.period.week,
        _Period.month => t.breathingStats.period.month,
        _Period.year => t.breathingStats.period.year,
        _Period.all => t.breathingStats.period.all,
      };

  /// Inclusive lower bound for this period, or null for "all time".
  DateTime? cutoff(DateTime now) => switch (this) {
        _Period.week => now.subtract(const Duration(days: 7)),
        _Period.month => now.subtract(const Duration(days: 30)),
        _Period.year => now.subtract(const Duration(days: 365)),
        _Period.all => null,
      };
}

/// Aggregate statistics for the Breathing module over a selectable time window.
/// Reuses [breathingJournalProvider] (the full session list) and aggregates on
/// the client — no extra fetch.
class BreathingStatsScreen extends ConsumerStatefulWidget {
  const BreathingStatsScreen({super.key});

  @override
  ConsumerState<BreathingStatsScreen> createState() =>
      _BreathingStatsScreenState();
}

class _BreathingStatsScreenState extends ConsumerState<BreathingStatsScreen> {
  _Period _period = _Period.week;

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
                    text: t.breathingStats.empty.loadError,
                  ),
                  data: (sessions) {
                    final now = DateTime.now();
                    final cutoff = _period.cutoff(now);
                    final scoped = cutoff == null
                        ? sessions
                        : sessions
                            .where((s) => s.completedAt.isAfter(cutoff))
                            .toList();
                    final stats = _Aggregate.from(scoped);

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                      children: [
                        _PeriodSelector(
                          c: c,
                          selected: _period,
                          onSelect: (p) => setState(() => _period = p),
                        ),
                        const SizedBox(height: 18),
                        if (stats.count == 0)
                          _Empty(
                            c: c,
                            text: t.breathingStats.empty.noSessions,
                          )
                        else ...[
                          _HeroHold(c: c, seconds: stats.bestHold),
                          const SizedBox(height: 14),
                          _StatsGrid(c: c, stats: stats),
                          const SizedBox(height: 14),
                          _MoodRow(c: c, stats: stats),
                        ],
                      ],
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

// ── Aggregation ────────────────────────────────────────────────

class _Aggregate {
  final int count;
  final int totalSeconds;
  final int totalBreaths;
  final int bestHold;
  final int totalRounds;
  final double? avgCalmness;
  final double? avgConfidence;

  const _Aggregate({
    required this.count,
    required this.totalSeconds,
    required this.totalBreaths,
    required this.bestHold,
    required this.totalRounds,
    required this.avgCalmness,
    required this.avgConfidence,
  });

  factory _Aggregate.from(List<BreathingSession> sessions) {
    int secs = 0, breaths = 0, best = 0, rounds = 0;
    int calmSum = 0, calmN = 0, confSum = 0, confN = 0;
    for (final s in sessions) {
      secs += s.durationSeconds;
      breaths += s.breaths;
      rounds += s.rounds;
      if (s.longestHoldSeconds > best) best = s.longestHoldSeconds;
      if (s.calmness != null) {
        calmSum += s.calmness!;
        calmN++;
      }
      if (s.confidence != null) {
        confSum += s.confidence!;
        confN++;
      }
    }
    return _Aggregate(
      count: sessions.length,
      totalSeconds: secs,
      totalBreaths: breaths,
      bestHold: best,
      totalRounds: rounds,
      avgCalmness: calmN == 0 ? null : calmSum / calmN,
      avgConfidence: confN == 0 ? null : confSum / confN,
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
              t.breathingStats.header.title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.insights_outlined,
              size: 20, color: kRimGold.withValues(alpha: 0.9)),
        ],
      ),
    );
  }
}

// ── Period selector ────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector(
      {required this.c, required this.selected, required this.onSelect});
  final SieColors c;
  final _Period selected;
  final ValueChanged<_Period> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (final p in _Period.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected == p
                        ? kRimGold.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == p ? kRimGold : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    p.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected == p ? c.textPrimary : c.textSecondary,
                      fontSize: 11.5,
                      fontWeight:
                          selected == p ? FontWeight.w700 : FontWeight.w500,
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

// ── Hero: best hold ────────────────────────────────────────────

class _HeroHold extends StatelessWidget {
  const _HeroHold({required this.c, required this.seconds});
  final SieColors c;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: c.surface,
        border: Border.all(color: kRimGold.withValues(alpha: 0.4)),
        boxShadow: c.isLightMode
            ? null
            : [BoxShadow(color: kRimGold.withValues(alpha: 0.12), blurRadius: 26)],
      ),
      child: Column(
        children: [
          Text(
            t.breathingStats.hero.label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            fmtDuration(seconds),
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 46,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              shadows: c.isLightMode
                  ? null
                  : [Shadow(color: kRimGold.withValues(alpha: 0.6), blurRadius: 18)],
            ),
          ),
          const SizedBox(height: 2),
          Text(t.breathingStats.hero.caption,
              style: TextStyle(color: c.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Stats grid ─────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.c, required this.stats});
  final SieColors c;
  final _Aggregate stats;

  @override
  Widget build(BuildContext context) {
    final cells = [
      _Cell(Icons.self_improvement_rounded, '${stats.count}',
          sessionsWord(stats.count)),
      _Cell(Icons.timer_outlined, fmtDuration(stats.totalSeconds),
          t.breathingStats.grid.totalTime),
      _Cell(Icons.air_rounded, '${stats.totalBreaths}',
          t.breathingStats.grid.totalBreaths),
      _Cell(Icons.repeat_rounded, '${stats.totalRounds}',
          t.breathingStats.grid.rounds),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [for (final cell in cells) _StatCard(c: c, cell: cell)],
    );
  }
}

class _Cell {
  final IconData icon;
  final String value;
  final String label;
  const _Cell(this.icon, this.value, this.label);
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.c, required this.cell});
  final SieColors c;
  final _Cell cell;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(cell.icon, size: 20, color: kRimGold.withValues(alpha: 0.9)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cell.value,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(cell.label,
                  style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Average mood row ───────────────────────────────────────────

class _MoodRow extends StatelessWidget {
  const _MoodRow({required this.c, required this.stats});
  final SieColors c;
  final _Aggregate stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AvgCard(
            c: c,
            title: t.breathingStats.mood.calmness,
            value: stats.avgCalmness,
            accent: c.accentSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AvgCard(
            c: c,
            title: t.breathingStats.mood.confidence,
            value: stats.avgConfidence,
            accent: c.accent,
          ),
        ),
      ],
    );
  }
}

class _AvgCard extends StatelessWidget {
  const _AvgCard({
    required this.c,
    required this.title,
    required this.value,
    required this.accent,
  });
  final SieColors c;
  final String title;
  final double? value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: c.textSecondary, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value == null ? '—' : value!.toStringAsFixed(1),
                style: TextStyle(
                  color: value == null ? c.textSecondary : accent,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (value != null)
                Text(' / 10',
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty ──────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({required this.c, required this.text});
  final SieColors c;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bubble_chart_outlined,
              size: 46, color: c.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}
