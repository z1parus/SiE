import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';

import 'breathing_reflection_screen.dart';

/// Post-session recovery screen (shown when enabled in the protocol settings).
///
/// The ambient music is handed over from the exercise screen still playing —
/// this screen deliberately does NOT stop it on entry. It keeps running while
/// the user lets their breath settle, and only fades out once they tap
/// "continue", at which point the reflection screen is revealed.
class BreathingRecoveryScreen extends ConsumerStatefulWidget {
  const BreathingRecoveryScreen({
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
  ConsumerState<BreathingRecoveryScreen> createState() =>
      _BreathingRecoveryScreenState();
}

class _BreathingRecoveryScreenState
    extends ConsumerState<BreathingRecoveryScreen> {
  bool _continuing = false;

  Future<void> _continue() async {
    if (_continuing) return;
    setState(() => _continuing = true);
    SieHaptics.selection();
    // The user is ready to move on — fade the ambient music out smoothly.
    await ref.read(audioServiceProvider).stopAll();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BreathingReflectionScreen(
          durationSeconds: widget.durationSeconds,
          breaths: widget.breaths,
          rounds: widget.rounds,
          longestHoldSeconds: widget.longestHoldSeconds,
          totalHoldSeconds: widget.totalHoldSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    final text = Theme.of(context).textTheme;

    return PopScope(
      // The session is over; the only way forward is the continue button.
      canPop: false,
      child: SieBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.spa_outlined, color: c.accent, size: 56),
                    const SizedBox(height: 28),
                    Text(
                      t.breathingExercise.recoveryScreen.title,
                      textAlign: TextAlign.center,
                      style: text.headlineMedium,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t.breathingExercise.recoveryScreen.subtitle,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(
                        color: c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 44),
                    _ContinueButton(
                      label: t.breathingExercise.recoveryScreen.continueButton,
                      busy: _continuing,
                      onTap: _continue,
                      c: c,
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

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.label,
    required this.busy,
    required this.onTap,
    required this.c,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;
  final SieColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        constraints: const BoxConstraints(minWidth: 260),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: c.accent.withValues(alpha: 0.12),
          border: Border.all(color: c.accent.withValues(alpha: 0.7)),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              )
            : Text(
                label,
                style: TextStyle(
                  color: c.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}
