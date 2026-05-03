import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sie_core/sie_core.dart';
import 'mission_accomplished_screen.dart';

// ── Settings ──────────────────────────────────────────────────

class BreathingSettings {
  final int rounds;
  final int cyclesPerRound;
  final int inhaleSecs;
  final int exhaleSecs;
  final int recoverySecs;
  final int exhaustRetentionSecs;

  const BreathingSettings({
    this.rounds = 3,
    this.cyclesPerRound = 30,
    this.inhaleSecs = 2,
    this.exhaleSecs = 2,
    this.recoverySecs = 15,
    this.exhaustRetentionSecs = 90,
  });

  BreathingSettings copyWith({
    int? rounds,
    int? cyclesPerRound,
    int? inhaleSecs,
    int? exhaleSecs,
    int? recoverySecs,
    int? exhaustRetentionSecs,
  }) =>
      BreathingSettings(
        rounds: rounds ?? this.rounds,
        cyclesPerRound: cyclesPerRound ?? this.cyclesPerRound,
        inhaleSecs: inhaleSecs ?? this.inhaleSecs,
        exhaleSecs: exhaleSecs ?? this.exhaleSecs,
        recoverySecs: recoverySecs ?? this.recoverySecs,
        exhaustRetentionSecs:
            exhaustRetentionSecs ?? this.exhaustRetentionSecs,
      );
}

// ── Phase ─────────────────────────────────────────────────────

enum _Phase { idle, active, retention, recovery, complete }

// ── Screen ───────────────────────────────────────────────────

class BreathingExerciseScreen extends ConsumerStatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  ConsumerState<BreathingExerciseScreen> createState() =>
      _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState
    extends ConsumerState<BreathingExerciseScreen>
    with TickerProviderStateMixin {
  late final AnimationController _circleCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  _Phase _phase = _Phase.idle;
  BreathingSettings _settings = const BreathingSettings();

  int _round = 1;
  int _cycle = 0;
  bool _isInhaling = true;
  int _retentionElapsed = 0;
  bool _recoveryInhaling = true;
  int _recoverySecsLeft = 0;

  Timer? _breathTimer;
  Timer? _retentionTimer;
  Timer? _recoveryTimer;
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    _circleCtrl = AnimationController(vsync: this, value: 0.3);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cancelTimers();
    _circleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _breathTimer?.cancel();
    _retentionTimer?.cancel();
    _recoveryTimer?.cancel();
  }

  // ── Back / Partial XP ────────────────────────────────────────

  void _onBack() {
    _cancelTimers();
    ref.read(audioServiceProvider).stopAll();
    _awardPartialXpIfEligible(); // fire-and-forget
    Navigator.of(context).pop();
  }

  Future<void> _awardPartialXpIfEligible() async {
    if (_sessionStart == null) return;
    if (_phase == _Phase.idle || _phase == _Phase.complete) return;
    final elapsed = DateTime.now().difference(_sessionStart!).inSeconds;
    if (elapsed < 30) return;
    try {
      await ref
          .read(sessionCompletionProvider.notifier)
          .completeSession(durationSeconds: elapsed);
      ref.invalidate(userProfileProvider);
    } catch (_) {}
  }

  // ── Phase: Active ─────────────────────────────────────────

  void _startSession() {
    _sessionStart = DateTime.now();
    _round = 1;
    _startActivePhase();
  }

  void _startActivePhase() {
    if (!mounted) return;
    _pulseCtrl.stop();
    setState(() {
      _phase = _Phase.active;
      _cycle = 0;
      _isInhaling = true;
    });
    _runNextCycle();
  }

  void _runNextCycle() {
    if (!mounted || _phase != _Phase.active) return;
    if (_cycle >= _settings.cyclesPerRound) {
      _startRetentionPhase();
      return;
    }
    setState(() => _isInhaling = true);
    ref.read(audioServiceProvider).playInhale(targetSecs: _settings.inhaleSecs);
    _circleCtrl.animateTo(
      1.0,
      duration: Duration(seconds: _settings.inhaleSecs),
      curve: Curves.easeIn,
    );
    _breathTimer = Timer(Duration(seconds: _settings.inhaleSecs), () {
      if (!mounted || _phase != _Phase.active) return;
      setState(() => _isInhaling = false);
      ref.read(audioServiceProvider).playExhale(targetSecs: _settings.exhaleSecs);
      _circleCtrl.animateTo(
        0.3,
        duration: Duration(seconds: _settings.exhaleSecs),
        curve: Curves.easeOut,
      );
      _breathTimer = Timer(Duration(seconds: _settings.exhaleSecs), () {
        if (!mounted || _phase != _Phase.active) return;
        setState(() => _cycle++);
        _runNextCycle();
      });
    });
  }

  // ── Phase: Retention ──────────────────────────────────────

  void _startRetentionPhase() {
    if (!mounted) return;
    _breathTimer?.cancel();
    setState(() {
      _phase = _Phase.retention;
      _retentionElapsed = 0;
    });
    _pulseCtrl.repeat(reverse: true);
    _retentionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _retentionElapsed + 1;
      if (next >= _settings.exhaustRetentionSecs) {
        t.cancel();
        setState(() => _retentionElapsed = next);
        _endRetention();
      } else {
        setState(() => _retentionElapsed = next);
      }
    });
  }

  void _endRetention() {
    _retentionTimer?.cancel();
    _pulseCtrl.stop();
    _startRecoveryPhase();
  }

  // ── Phase: Recovery ───────────────────────────────────────

  void _startRecoveryPhase() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.recovery;
      _recoveryInhaling = true;
      _recoverySecsLeft = _settings.recoverySecs;
    });
    ref.read(audioServiceProvider).playInhale(targetSecs: 3);
    _circleCtrl.animateTo(
      1.0,
      duration: const Duration(seconds: 3),
      curve: Curves.easeIn,
    );
    _breathTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _phase != _Phase.recovery) return;
      setState(() => _recoveryInhaling = false);
      _recoveryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        final next = _recoverySecsLeft - 1;
        if (next <= 0) {
          t.cancel();
          _endRecovery();
        } else {
          setState(() => _recoverySecsLeft = next);
        }
      });
    });
  }

  void _endRecovery() {
    _recoveryTimer?.cancel();
    if (!mounted) return;
    if (_round < _settings.rounds) {
      setState(() => _round++);
      _startActivePhase();
    } else {
      _completeSession();
    }
  }

  // ── Session Complete ──────────────────────────────────────

  Future<void> _completeSession() async {
    if (!mounted) return;
    _cancelTimers();
    ref.read(audioServiceProvider).stopAll();
    setState(() => _phase = _Phase.complete);

    final elapsed = _sessionStart == null
        ? 60
        : DateTime.now().difference(_sessionStart!).inSeconds;

    final result = await ref
        .read(sessionCompletionProvider.notifier)
        .completeSession(durationSeconds: elapsed);

    ref.invalidate(userProfileProvider);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => MissionAccomplishedScreen(
          xpGained: result.xpGained,
          achievement: result.newAchievement,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  // ── Settings Sheet ────────────────────────────────────────

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SieTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        side: BorderSide(color: SieTheme.borderDefault),
      ),
      builder: (_) => _SettingsSheet(
        settings: _settings,
        onChanged: (s) => setState(() => _settings = s),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: _TopBar(
                phase: _phase,
                round: _round,
                totalRounds: _settings.rounds,
                onBack: _onBack,
              ),
            ),
            Center(child: _buildCircle()),
            Positioned(
              bottom: 40, left: 32, right: 32,
              child: _buildBottomArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircle() {
    final circle = AnimatedBuilder(
      animation: _circleCtrl,
      builder: (_, _) {
        final t = _circleCtrl.value;
        final size = 130.0 + (t * 130.0);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SieTheme.accent.withValues(alpha: 0.06 + t * 0.08),
            border: Border.all(
              color: SieTheme.accent.withValues(alpha: 0.35 + t * 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: SieTheme.accent.withValues(alpha: t * 0.35),
                blurRadius: 48,
                spreadRadius: 8,
              ),
            ],
          ),
        );
      },
    );

    if (_phase == _Phase.retention) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) =>
            Transform.scale(scale: _pulseAnim.value, child: child),
        child: circle,
      );
    }
    return circle;
  }

  Widget _buildBottomArea() {
    switch (_phase) {
      case _Phase.idle:
        return Column(
          children: [
            Text(
              'WIM HOF METHOD',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${_settings.rounds} ROUNDS  ·  ${_settings.cyclesPerRound} CYCLES',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _SettingsButton(onTap: _showSettings),
            const SizedBox(height: 16),
            _SieButton(
              label: 'INITIATE PROTOCOL',
              onPressed: () {
                ref.read(audioServiceProvider).startAmbient();
                _startSession();
              },
            ),
          ],
        );

      case _Phase.active:
        return Column(
          children: [
            Text(
              _isInhaling ? 'INHALE' : 'EXHALE',
              style: const TextStyle(
                color: SieTheme.accent,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'CYCLE ${_cycle + 1} / ${_settings.cyclesPerRound}',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        );

      case _Phase.retention:
        final mins = _retentionElapsed ~/ 60;
        final secs = _retentionElapsed % 60;
        return Column(
          children: [
            const Text(
              'HOLD',
              style: TextStyle(
                color: SieTheme.accentSecondary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: SieTheme.textPrimary,
                fontSize: 42,
                fontWeight: FontWeight.w200,
                letterSpacing: 6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'MAX ${_settings.exhaustRetentionSecs ~/ 60}:${(_settings.exhaustRetentionSecs % 60).toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            _SieButton(label: 'RELEASE', onPressed: _endRetention),
          ],
        );

      case _Phase.recovery:
        return Column(
          children: [
            Text(
              _recoveryInhaling ? 'INHALE DEEPLY' : 'HOLD',
              style: const TextStyle(
                color: SieTheme.accent,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
            ),
            if (!_recoveryInhaling) ...[
              const SizedBox(height: 10),
              Text(
                '${_recoverySecsLeft}s',
                style: const TextStyle(
                  color: SieTheme.textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );

      case _Phase.complete:
        return const Center(
          child: CircularProgressIndicator(
            color: SieTheme.accent,
            strokeWidth: 1.5,
          ),
        );
    }
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final _Phase phase;
  final int round;
  final int totalRounds;
  final VoidCallback onBack;

  const _TopBar({
    required this.phase,
    required this.round,
    required this.totalRounds,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: SieTheme.textSecondary,
              size: 18,
            ),
          ),
          const Spacer(),
          if (phase != _Phase.idle)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: SieTheme.borderAccent),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                'ROUND $round / $totalRounds',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          const Spacer(),
          // Placeholder to keep round badge visually centered
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Settings Button (idle phase, centered) ────────────────────

class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: SieTheme.borderDefault),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 20, color: SieTheme.textSecondary),
              const SizedBox(width: 10),
              Text(
                'PROTOCOL SETTINGS',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings Sheet ────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  final BreathingSettings settings;
  final ValueChanged<BreathingSettings> onChanged;

  const _SettingsSheet({required this.settings, required this.onChanged});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late BreathingSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
  }

  void _update(BreathingSettings s) {
    setState(() => _s = s);
    widget.onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PROTOCOL SETTINGS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          _SettingRow(
            label: 'ROUNDS',
            value: _s.rounds,
            min: 1,
            max: 5,
            onChanged: (v) => _update(_s.copyWith(rounds: v)),
          ),
          _SettingRow(
            label: 'CYCLES / ROUND',
            value: _s.cyclesPerRound,
            min: 10,
            max: 40,
            step: 5,
            onChanged: (v) => _update(_s.copyWith(cyclesPerRound: v)),
          ),
          _SettingRow(
            label: 'INHALE  (SEC)',
            value: _s.inhaleSecs,
            min: 1,
            max: 5,
            onChanged: (v) => _update(_s.copyWith(inhaleSecs: v)),
          ),
          _SettingRow(
            label: 'EXHALE  (SEC)',
            value: _s.exhaleSecs,
            min: 1,
            max: 5,
            onChanged: (v) => _update(_s.copyWith(exhaleSecs: v)),
          ),
          _SettingRow(
            label: 'RECOVERY (SEC)',
            value: _s.recoverySecs,
            min: 10,
            max: 30,
            onChanged: (v) => _update(_s.copyWith(recoverySecs: v)),
          ),
          _SettingRow(
            label: 'EXHALE RETENTION (SEC)',
            value: _s.exhaustRetentionSecs,
            min: 30,
            max: 180,
            step: 15,
            onChanged: (v) => _update(_s.copyWith(exhaustRetentionSecs: v)),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _SettingRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          _StepBtn(
            icon: Icons.remove,
            active: value > min,
            onTap: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SieTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 20),
          _StepBtn(
            icon: Icons.add,
            active: value < max,
            onTap: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(
            color: active ? SieTheme.borderAccent : SieTheme.borderDefault,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? SieTheme.accent : SieTheme.textSecondary,
        ),
      ),
    );
  }
}

// ── Shared Button ─────────────────────────────────────────────

class _SieButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SieButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: SieTheme.accent),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: SieTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}
