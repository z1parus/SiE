import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

/// Ecosystem Pillar 3 — the detailed "Life Balance" view: activity across all
/// six life areas over the last 7 days, drawn from habits, goals and sessions.
class LifeAreasScreen extends ConsumerWidget {
  const LifeAreasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final async = ref.watch(lifeAreasProvider);

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.operationalBrief.areas.screenTitle,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Text(
                t.operationalBrief.areas.screenSubtitle,
                style: TextStyle(color: c.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
        body: async.when(
          loading: () => const Center(child: SieSkeleton(width: 200, height: 16)),
          error: (_, __) => const SieErrorState(),
          data: (areas) {
            final maxScore = areas.maxScore;
            final neglected = areas.neglected;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                for (final area in LifeArea.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AreaCard(
                      area: area,
                      stat: areas.statFor(area),
                      maxScore: maxScore,
                      neglected: area == neglected,
                      c: c,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final LifeArea area;
  final LifeAreaStat stat;
  final int maxScore;
  final bool neglected;
  final SieColors c;
  const _AreaCard({
    required this.area,
    required this.stat,
    required this.maxScore,
    required this.neglected,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxScore > 0 ? (stat.score / maxScore).clamp(0.0, 1.0) : 0.0;
    final barColor = neglected ? c.warning : c.accent;

    return Container(
      decoration: c.flatCard(radius: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(area.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                area.label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (stat.minutes > 0)
                Text('${stat.minutes}′',
                    style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 6, color: c.border.withValues(alpha: 0.5)),
                LayoutBuilder(
                  builder: (_, cst) => Container(
                    height: 6,
                    width: cst.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            [
              t.operationalBrief.areas.statHabits(n: stat.habits),
              t.operationalBrief.areas.statGoals(n: stat.goals),
              t.operationalBrief.areas.statSessions(n: stat.sessions),
            ].join('  ·  '),
            style: TextStyle(color: c.textSecondary, fontSize: 11),
          ),
          if (neglected) ...[
            const SizedBox(height: 8),
            Text(
              t.operationalBrief.areas.suggestFocus,
              style: TextStyle(
                color: c.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
