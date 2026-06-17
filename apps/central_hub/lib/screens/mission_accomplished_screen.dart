import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

class MissionAccomplishedScreen extends ConsumerStatefulWidget {
  final int xpGained;
  final int dpGained;
  final Achievement? achievement;
  final MissionMedal? medal;
  final String subtitle;

  const MissionAccomplishedScreen({
    super.key,
    required this.xpGained,
    this.dpGained = 0,
    this.achievement,
    this.medal,
    this.subtitle = 'BREATHING PROTOCOL COMPLETE',
  });

  @override
  ConsumerState<MissionAccomplishedScreen> createState() =>
      _MissionAccomplishedScreenState();
}

class _MissionAccomplishedScreenState
    extends ConsumerState<MissionAccomplishedScreen>
    with TickerProviderStateMixin {
  late final AnimationController _medalCtrl;
  late final AnimationController _contentCtrl;
  late final Animation<double> _medalScale;
  late final Animation<double> _medalOpacity;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _medalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _medalScale = CurvedAnimation(
      parent: _medalCtrl,
      curve: Curves.elasticOut,
    );
    _medalOpacity = CurvedAnimation(
      parent: _medalCtrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );
    _contentOpacity = CurvedAnimation(
      parent: _contentCtrl,
      curve: Curves.easeIn,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));

    _medalCtrl.forward().then((_) {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _medalCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalXp = ref.watch(userProfileProvider).valueOrNull?.totalXp ?? 0;

    return SieBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height
                    - MediaQuery.of(context).padding.top
                    - MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _medalScale,
                  child: FadeTransition(
                    opacity: _medalOpacity,
                    child: widget.medal != null
                        ? _GoalMedalWidget(medal: widget.medal!)
                        : const _MedalWidget(),
                  ),
                ),
                const SizedBox(height: 52),
                FadeTransition(
                  opacity: _contentOpacity,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Column(
                      children: [
                        Text(
                          'MISSION ACCOMPLISHED',
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        _XpPanel(xpGained: widget.xpGained, totalXp: totalXp),
                        if (widget.dpGained > 0) ...[
                          const SizedBox(height: 10),
                          _DpPanel(dpGained: widget.dpGained),
                        ],
                        if (widget.achievement != null) ...[
                          const SizedBox(height: 16),
                          _AchievementPanel(achievement: widget.achievement!),
                        ],
                        const SizedBox(height: 48),
                        _ReturnButton(
                          onPressed: () =>
                              Navigator.of(context).popUntil((r) => r.isFirst),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Goal Medal Widget ─────────────────────────────────────────

class _GoalMedalWidget extends StatelessWidget {
  const _GoalMedalWidget({required this.medal});

  final MissionMedal medal;

  @override
  Widget build(BuildContext context) {
    final levelColor = medalLevelColor(medal.level);
    final icon       = categoryIconData(medal.category);
    final catColor   = categoryIconColor(medal.category);
    final isGold     = medal.level == 3;

    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: levelColor.withValues(alpha: 0.1),
        border: Border.all(color: levelColor, width: isGold ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: (isGold ? catColor : levelColor).withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, size: 52, color: catColor),
    );
  }
}

// ── Medal ─────────────────────────────────────────────────────

class _MedalWidget extends ConsumerWidget {
  const _MedalWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.surface,
        border: Border.all(color: c.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.20),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(Icons.air_rounded, size: 56, color: c.accent),
    );
  }
}

// ── XP Panel ──────────────────────────────────────────────────

class _XpPanel extends ConsumerWidget {
  final int xpGained;
  final int totalXp;

  const _XpPanel({required this.xpGained, required this.totalXp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: c.flatCard(radius: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('XP GAINED', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(
                'TOTAL: $totalXp XP',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 11),
              ),
            ],
          ),
          Text(
            '+$xpGained XP',
            style: TextStyle(
              color: c.accent,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── DP Panel ──────────────────────────────────────────────────

class _DpPanel extends ConsumerWidget {
  final int dpGained;
  const _DpPanel({required this.dpGained});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.dp.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: c.isLightMode
            ? const [
                BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 12,
                    offset: Offset(0, 2))
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined,
                  size: 14, color: c.dp.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              Text('DP GAINED', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          Text(
            '+$dpGained DP',
            style: TextStyle(
              color: c.dp,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Achievement Panel ─────────────────────────────────────────

class _AchievementPanel extends ConsumerWidget {
  final Achievement achievement;

  const _AchievementPanel({required this.achievement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.accent.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: c.isLightMode
            ? const [
                BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 12,
                    offset: Offset(0, 2))
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accent.withValues(alpha: 0.12),
              border: Border.all(color: c.accent),
            ),
            child: Icon(Icons.military_tech, color: c.accent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACHIEVEMENT UNLOCKED',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Return Button ─────────────────────────────────────────────

class _ReturnButton extends ConsumerWidget {
  final VoidCallback onPressed;

  const _ReturnButton({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: c.accent),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          'RETURN TO OPERATIONS',
          style: TextStyle(
            color: c.accent,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }
}
