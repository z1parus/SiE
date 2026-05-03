import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

class MissionAccomplishedScreen extends ConsumerStatefulWidget {
  final int xpGained;
  final Achievement? achievement;

  const MissionAccomplishedScreen({
    super.key,
    required this.xpGained,
    this.achievement,
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated medal
              ScaleTransition(
                scale: _medalScale,
                child: FadeTransition(
                  opacity: _medalOpacity,
                  child: const _MedalWidget(),
                ),
              ),
              const SizedBox(height: 52),
              // Content reveal
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
                        'BREATHING PROTOCOL COMPLETE',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),
                      _XpPanel(xpGained: widget.xpGained, totalXp: totalXp),
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
    );
  }
}

// ── Medal ─────────────────────────────────────────────────────

class _MedalWidget extends StatelessWidget {
  const _MedalWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SieTheme.surface,
        border: Border.all(color: SieTheme.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: SieTheme.accent.withValues(alpha:0.45),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
      child: const Icon(Icons.air_rounded, size: 56, color: SieTheme.accent),
    );
  }
}

// ── XP Panel ──────────────────────────────────────────────────

class _XpPanel extends StatelessWidget {
  final int xpGained;
  final int totalXp;

  const _XpPanel({required this.xpGained, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: SieTheme.surface,
        border: Border.all(color: SieTheme.borderAccent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'XP GAINED',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'TOTAL: $totalXp XP',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                    ),
              ),
            ],
          ),
          Text(
            '+$xpGained XP',
            style: const TextStyle(
              color: SieTheme.accent,
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

// ── Achievement Panel ─────────────────────────────────────────

class _AchievementPanel extends StatelessWidget {
  final Achievement achievement;

  const _AchievementPanel({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SieTheme.surfaceAlt,
        border: Border.all(color: SieTheme.accent.withValues(alpha:0.45)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SieTheme.accent.withValues(alpha:0.12),
              border: Border.all(color: SieTheme.accent),
            ),
            child:
                const Icon(Icons.military_tech, color: SieTheme.accent, size: 22),
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

class _ReturnButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ReturnButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: SieTheme.accent),
          borderRadius: BorderRadius.circular(2),
        ),
        child: const Text(
          'RETURN TO OPERATIONS',
          style: TextStyle(
            color: SieTheme.accent,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }
}
