import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'breathing_format.dart';
import 'mission_accomplished_screen.dart';
import 'session_orb_painters.dart';

/// Shown the moment a breathing session ends, BEFORE the XP reward screen. The
/// user records how they feel (mood emoji + calmness/confidence 1-10), then we
/// log the full session and reveal the reward. The reflection is optional —
/// "Пропустить" logs the session with no mood.
class BreathingReflectionScreen extends ConsumerStatefulWidget {
  const BreathingReflectionScreen({
    super.key,
    required this.durationSeconds,
    required this.breaths,
    required this.rounds,
    required this.longestHoldSeconds,
    required this.totalHoldSeconds,
  });

  final int durationSeconds;
  final int breaths;
  final int rounds;
  final int longestHoldSeconds;
  final int totalHoldSeconds;

  @override
  ConsumerState<BreathingReflectionScreen> createState() =>
      _BreathingReflectionScreenState();
}

class _BreathingReflectionScreenState
    extends ConsumerState<BreathingReflectionScreen> {
  int? _moodIndex;
  int? _calmness;
  int? _confidence;
  bool _saving = false;

  Future<void> _finish({required bool withReflection}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result =
          await ref.read(sessionCompletionProvider.notifier).completeSession(
                durationSeconds: widget.durationSeconds,
                breaths: widget.breaths,
                rounds: widget.rounds,
                longestHoldSeconds: widget.longestHoldSeconds,
                totalHoldSeconds: widget.totalHoldSeconds,
                moodEmoji: withReflection && _moodIndex != null
                    ? kBreathingMoods[_moodIndex!].emoji
                    : null,
                calmness: withReflection ? _calmness : null,
                confidence: withReflection ? _confidence : null,
              );
      ref.invalidate(userProfileProvider);
      ref.invalidate(breathingJournalProvider);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MissionAccomplishedScreen(
            xpGained: result.xpGained,
            dpGained: result.dpGained,
            achievement: result.newAchievement,
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _finish(withReflection: false);
      },
      child: SieBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'ПРАКТИКА ЗАВЕРШЕНА',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kRimGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SummaryCard(
                        c: c,
                        durationSeconds: widget.durationSeconds,
                        breaths: widget.breaths,
                        longestHoldSeconds: widget.longestHoldSeconds,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Как вы себя чувствуете?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MoodPicker(
                        c: c,
                        selected: _moodIndex,
                        onPick: (i) => setState(() => _moodIndex = i),
                      ),
                      const SizedBox(height: 28),
                      _LevelSection(
                        c: c,
                        title: 'СПОКОЙСТВИЕ',
                        accent: c.accentSecondary,
                        value: _calmness,
                        onPick: (v) => setState(() => _calmness = v),
                      ),
                      const SizedBox(height: 24),
                      _LevelSection(
                        c: c,
                        title: 'УВЕРЕННОСТЬ',
                        accent: c.accent,
                        value: _confidence,
                        onPick: (v) => setState(() => _confidence = v),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PrimaryButton(
                        c: c,
                        label: 'СОХРАНИТЬ',
                        busy: _saving,
                        onTap: () => _finish(withReflection: true),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed:
                            _saving ? null : () => _finish(withReflection: false),
                        child: Text(
                          'Пропустить',
                          style: TextStyle(
                            color: c.textSecondary.withValues(alpha: 0.7),
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Session summary ────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.c,
    required this.durationSeconds,
    required this.breaths,
    required this.longestHoldSeconds,
  });

  final SieColors c;
  final int durationSeconds;
  final int breaths;
  final int longestHoldSeconds;

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, String value, String label) => Column(
          children: [
            Icon(icon, size: 20, color: kRimGold.withValues(alpha: 0.9)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: c.flatCard(radius: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          stat(Icons.timer_outlined, fmtDuration(durationSeconds), 'время'),
          stat(Icons.air_rounded, '$breaths', breathsWord(breaths)),
          stat(Icons.hourglass_bottom_rounded,
              fmtDuration(longestHoldSeconds), 'задержка'),
        ],
      ),
    );
  }
}

// ── Mood picker ────────────────────────────────────────────────

class _MoodPicker extends StatelessWidget {
  const _MoodPicker(
      {required this.c, required this.selected, required this.onPick});
  final SieColors c;
  final int? selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < kBreathingMoods.length; i++)
          _MoodChip(
            mood: kBreathingMoods[i],
            selected: selected == i,
            c: c,
            onTap: () => onPick(i),
          ),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip(
      {required this.mood,
      required this.selected,
      required this.c,
      required this.onTap});
  final BreathingMood mood;
  final bool selected;
  final SieColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? kRimGold.withValues(alpha: 0.14)
              : (c.isLightMode ? Colors.white : c.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kRimGold : c.border,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected && !c.isLightMode
              ? [BoxShadow(color: kRimGold.withValues(alpha: 0.2), blurRadius: 14)]
              : null,
        ),
        child: Column(
          children: [
            Text(mood.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              mood.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? c.textPrimary : c.textSecondary,
                fontSize: 9,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 1..10 level selector ───────────────────────────────────────

class _LevelSection extends StatelessWidget {
  const _LevelSection({
    required this.c,
    required this.title,
    required this.accent,
    required this.value,
    required this.onPick,
  });
  final SieColors c;
  final String title;
  final Color accent;
  final int? value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            Text(
              value == null ? '—' : '$value / 10',
              style: TextStyle(
                  color: value == null ? c.textSecondary : accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (var n = 1; n <= 10; n++)
              _LevelDot(
                n: n,
                selected: value == n,
                accent: accent,
                c: c,
                onTap: () => onPick(n),
              ),
          ],
        ),
      ],
    );
  }
}

class _LevelDot extends StatelessWidget {
  const _LevelDot({
    required this.n,
    required this.selected,
    required this.accent,
    required this.c,
    required this.onTap,
  });
  final int n;
  final bool selected;
  final Color accent;
  final SieColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 30,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? accent : c.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          '$n',
          style: TextStyle(
            color: selected ? accent : c.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Primary button ─────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.c,
      required this.label,
      required this.busy,
      required this.onTap});
  final SieColors c;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kRimGold.withValues(alpha: 0.85)),
          color: kRimGold.withValues(alpha: 0.10),
          boxShadow: c.isLightMode
              ? null
              : [BoxShadow(color: kRimGold.withValues(alpha: 0.18), blurRadius: 22)],
        ),
        child: busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kRimGold),
              )
            : Text(
                label,
                style: TextStyle(
                  color: kRimGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
      ),
    );
  }
}
