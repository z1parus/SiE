import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:sie_core/sie_core.dart';
import 'mission_accomplished_screen.dart';

// ── Design tokens ──────────────────────────────────────────────
const _kCyan   = Color(0xFF00E5FF);
const _kPurple = Color(0xFF7000FF);

// ── Shared HUD glass settings ──────────────────────────────────
LiquidGlassSettings _hudGlass({double blur = 3.0, double glow = 0.88}) =>
    LiquidGlassSettings(
      blur: blur, thickness: 24, refractiveIndex: 1.45,
      glassColor: const Color(0x0A0A0E1A),
      lightAngle: GlassDefaults.lightAngle, lightIntensity: 0.72,
      glowIntensity: glow, saturation: 1.4,
      specularSharpness: GlassSpecularSharpness.sharp,
      ambientStrength: 0.08, chromaticAberration: 0.015,
    );

// ── Settings ──────────────────────────────────────────────────

class BreathingSettings {
  final int rounds;
  final int cyclesPerRound;
  final int inhaleSecs;
  final int exhaleSecs;
  final int exhaustRetentionSecs;

  const BreathingSettings({
    this.rounds = 3,
    this.cyclesPerRound = 30,
    this.inhaleSecs = 2,
    this.exhaleSecs = 2,
    this.exhaustRetentionSecs = 90,
  });

  BreathingSettings copyWith({
    int? rounds,
    int? cyclesPerRound,
    int? inhaleSecs,
    int? exhaleSecs,
    int? exhaustRetentionSecs,
  }) =>
      BreathingSettings(
        rounds: rounds ?? this.rounds,
        cyclesPerRound: cyclesPerRound ?? this.cyclesPerRound,
        inhaleSecs: inhaleSecs ?? this.inhaleSecs,
        exhaleSecs: exhaleSecs ?? this.exhaleSecs,
        exhaustRetentionSecs:
            exhaustRetentionSecs ?? this.exhaustRetentionSecs,
      );
}

// ── Phase ─────────────────────────────────────────────────────

enum _Phase { idle, countdown, active, retention, recovery, roundTransition, complete }

const _recoveryHoldSecs = 15;

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
  late final AudioService _audio;

  _Phase _phase = _Phase.idle;
  BreathingSettings _settings = const BreathingSettings();

  bool _onboardingDismissed = false;
  bool _showOnboardingManual = false;

  int _round = 1;
  int _cycle = 0;
  bool _isInhaling = true;
  int _retentionElapsed = 0;
  int _recoveryElapsed = 0;
  int _transitionElapsed = 0;
  int _countdownValue = 5;
  bool _spherePressed = false;

  Timer? _breathTimer;
  Timer? _retentionTimer;
  Timer? _transitionTimer;
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    // Capture before dispose() where ref is no longer valid.
    _audio = ref.read(audioServiceProvider);
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
    _audio.stopAll();
    _circleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _breathTimer?.cancel();
    _retentionTimer?.cancel();
    _transitionTimer?.cancel();
  }

  // ── Back / Partial XP ────────────────────────────────────────

  void _onBack() {
    _cancelTimers();
    _audio.stopAll(); // fade-out, fire-and-forget
    _awardPartialXpIfEligible();
    Navigator.of(context).pop();
  }

  void _onSphereTap() {
    if (_phase == _Phase.idle) _startSession();
    // When a session is in progress, tapping the sphere is a no-op.
  }

  Future<void> _awardPartialXpIfEligible() async {
    if (_sessionStart == null) return;
    if (_phase == _Phase.idle ||
        _phase == _Phase.countdown ||
        _phase == _Phase.complete) {
      return;
    }
    final elapsed = DateTime.now().difference(_sessionStart!).inSeconds;
    if (elapsed < 30) return;
    try {
      await ref
          .read(sessionCompletionProvider.notifier)
          .completeSession(durationSeconds: elapsed);
      ref.invalidate(userProfileProvider);
    } catch (_) {}
  }

  // ── Phase: Countdown ──────────────────────────────────────

  void _startSession() {
    _round = 1;
    _startCountdown();
  }

  void _startCountdown() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.countdown;
      _countdownValue = 5;
    });
    _audio.startAmbient(); // fade-in begins now
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _countdownValue - 1;
      if (next <= 0) {
        t.cancel();
        setState(() => _countdownValue = 0);
        _sessionStart = DateTime.now();
        _startActivePhase();
      } else {
        setState(() => _countdownValue = next);
      }
    });
  }

  // ── Phase: Active ─────────────────────────────────────────

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
    _audio.playInhale(targetSecs: _settings.inhaleSecs);
    _circleCtrl.animateTo(
      1.0,
      duration: Duration(seconds: _settings.inhaleSecs),
      curve: Curves.easeIn,
    );
    _breathTimer = Timer(Duration(seconds: _settings.inhaleSecs), () {
      if (!mounted || _phase != _Phase.active) return;
      setState(() => _isInhaling = false);
      _audio.playExhale(targetSecs: _settings.exhaleSecs);
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

  // ── Phase: Recovery (Phase 3 — Hold on Inhale) ────────────

  void _startRecoveryPhase() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.recovery;
      _recoveryElapsed = 0;
    });
    // Deep inhale: circle expands to maximum over 3 s with matching audio.
    _audio.playInhale(targetSecs: 3);
    _circleCtrl.animateTo(
      1.0,
      duration: const Duration(seconds: 3),
      curve: Curves.easeIn,
    );
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _recoveryElapsed + 1;
      setState(() => _recoveryElapsed = next);
      if (next >= _recoveryHoldSecs) {
        t.cancel();
        _startRoundTransitionPhase();
      }
    });
  }

  // ── Phase: Round Transition ───────────────────────────────

  void _startRoundTransitionPhase() {
    if (!mounted) return;
    // Establish max size at phase entry so the exhale animation has full
    // visual range. Retention ended with the circle at its minimum.
    _circleCtrl.value = 1.0;
    setState(() {
      _phase = _Phase.roundTransition;
      _transitionElapsed = 0;
    });
    // First 5 s: exhale — circle shrinks to minimum with matching audio.
    // AudioService fade-out timer ensures the cue naturally ends at T+5 s.
    _audio.playExhale(targetSecs: 5);
    _circleCtrl.animateTo(
      0.3,
      duration: const Duration(seconds: 5),
      curve: Curves.easeOut,
    );
    // Second 5 s: circle is static at minimum, no breathing sound.
    _transitionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _transitionElapsed + 1;
      setState(() => _transitionElapsed = next);
      if (next >= 10) {
        t.cancel();
        _endTransition();
      }
    });
  }

  void _endTransition() {
    _transitionTimer?.cancel();
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
    setState(() => _phase = _Phase.complete);

    final elapsed = _sessionStart == null
        ? 60
        : DateTime.now().difference(_sessionStart!).inSeconds;

    // Fade-out and DB write run in parallel; UI shows spinner during both.
    final stopFuture = _audio.stopAll();
    final dbFuture = ref
        .read(sessionCompletionProvider.notifier)
        .completeSession(durationSeconds: elapsed);

    await stopFuture;
    final result = await dbFuture;

    ref.invalidate(userProfileProvider);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => MissionAccomplishedScreen(
          xpGained: result.xpGained,
          dpGained: result.dpGained,
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
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final showOnboarding = _showOnboardingManual ||
        (!_onboardingDismissed &&
            profile != null &&
            !profile.hasSeenOnboardingBreathing);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Layer 0: Deterministic three-tier starfield.
              const Positioned.fill(child: SieSpaceBackground()),
              SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: _TopBar(
                        phase: _phase,
                        round: _round,
                        totalRounds: _settings.rounds,
                        onBack: _onBack,
                        onInfo: () => setState(() => _showOnboardingManual = true),
                      ),
                    ),
                    Center(
                      child: GestureDetector(
                        onTap: _onSphereTap,
                        onTapDown: (_) {
                          if (_phase == _Phase.idle) {
                            setState(() => _spherePressed = true);
                          }
                        },
                        onTapUp: (_) => setState(() => _spherePressed = false),
                        onTapCancel: () => setState(() => _spherePressed = false),
                        child: AnimatedScale(
                          scale: (_phase == _Phase.idle && _spherePressed) ? 0.95 : 1.0,
                          duration: const Duration(milliseconds: 80),
                          child: _buildCircle(),
                        ),
                      ),
                    ),
                    if (_phase == _Phase.countdown)
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.7, end: 1.0).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Text(
                            '$_countdownValue',
                            key: ValueKey(_countdownValue),
                            style: const TextStyle(
                              color: _kCyan,
                              fontSize: 80,
                              fontWeight: FontWeight.w100,
                              letterSpacing: 4,
                              shadows: [
                                Shadow(color: _kCyan, blurRadius: 20),
                                Shadow(color: _kCyan, blurRadius: 60),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 40, left: 32, right: 32,
                      child: _buildBottomArea(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned.fill(child: AudioInitOverlay()),
        Positioned.fill(
          child: OnboardingOverlay(
            visible: showOnboarding,
            moduleLabel: 'ДЫХАНИЕ',
            description: 'Сброс нервной системы и насыщение кислородом.',
            benefit:
                'Моментальное снижение стресса, управляемый выброс адреналина '
                'и ясность ума через гипервентиляцию с задержкой дыхания.',
            onAccept: () {
              if (_showOnboardingManual) {
                setState(() => _showOnboardingManual = false);
              } else {
                setState(() => _onboardingDismissed = true);
                markOnboardingSeen('breathing');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCircle() {
    return AnimatedBuilder(
      animation: Listenable.merge([_circleCtrl, _pulseAnim]),
      builder: (_, _) {
        final t     = _circleCtrl.value;
        final pulse = (_phase == _Phase.retention) ? _pulseAnim.value : 1.0;
        final size  = (130.0 + t * 130.0) * pulse;

        final bool isRetention = _phase == _Phase.retention;
        final bool isInhale    = _phase == _Phase.active && _isInhaling;
        final bool isExhale    = _phase == _Phase.active && !_isInhaling;

        // Accent colour follows the breath direction.
        final Color accent = (isRetention || isExhale) ? _kPurple : _kCyan;

        // Frost blur deepens as the sphere expands; retention gets a fixed
        // dreamy value independent of the paused _circleCtrl.
        final double blur = isRetention ? 4.5 : (2.0 + t * 3.5).clamp(2.0, 5.5);

        // Glow intensity synced to breath phase:
        //   inhale  → 0.55 at min, 1.10 at full expansion
        //   exhale  → 0.40 at min, 0.90 at max
        //   hold    → 0.70 pulsing to 0.98 with _pulseAnim
        final double glow = isRetention
            ? 0.70 + (pulse - 0.92) * 3.5
            : isInhale
                ? 0.55 + t * 0.55
                : 0.40 + t * 0.50;

        final Color glassColor = accent.withValues(
          alpha: isRetention
              ? 0.09
              : isInhale
                  ? 0.03 + t * 0.07
                  : 0.04 + t * 0.04,
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer diffuse corona — painted behind the glass surface.
            Container(
              width: size + 52,
              height: size + 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(
                      alpha: t * 0.24 * (isRetention ? pulse : 1.0),
                    ),
                    blurRadius: 80,
                  ),
                ],
              ),
            ),

            // Shader glass sphere — the primary visual element.
            GlassCard(
              width: size,
              height: size,
              padding: EdgeInsets.zero,
              shape: LiquidRoundedSuperellipse(borderRadius: size / 2),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: LiquidGlassSettings(
                blur: blur,
                thickness: 36,
                refractiveIndex: 1.55,
                glassColor: glassColor,
                lightAngle: GlassDefaults.lightAngle,
                lightIntensity: 0.92,
                glowIntensity: glow.clamp(0.0, 1.2),
                saturation: 1.65,
                specularSharpness: GlassSpecularSharpness.sharp,
                ambientStrength: 0.14,
                chromaticAberration: 0.030,
              ),
              child: switch (_phase) {
                // Tap hint only visible when idle.
                _Phase.idle => Center(
                    child: Icon(
                      Icons.fingerprint,
                      color: _kCyan.withValues(alpha: 0.35),
                      size: 36,
                    ),
                  ),
                // Purple plasma core during breath-hold retention.
                _Phase.retention => Center(
                    child: Container(
                      width: size * 0.30,
                      height: size * 0.30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _kPurple.withValues(alpha: 0.28),
                            _kPurple.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomArea() {
    switch (_phase) {

      // ── Idle ──────────────────────────────────────────────────
      case _Phase.idle:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: LiquidRoundedSuperellipse(borderRadius: 20),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: _hudGlass(blur: 3.5, glow: 0.90),
              child: Column(
                children: [
                  const Text(
                    'WIM HOF METHOD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_settings.rounds} ROUNDS  ·  ${_settings.cyclesPerRound} CYCLES',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TAP SPHERE TO START',
                    style: TextStyle(
                      color: _kCyan.withValues(alpha: 0.55),
                      fontSize: 11,
                      letterSpacing: 2.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsButton(onTap: _showSettings),
            const SizedBox(height: 16),
            _SieButton(label: 'INITIATE PROTOCOL', onPressed: _startSession),
          ],
        );

      // ── Countdown ─────────────────────────────────────────────
      case _Phase.countdown:
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: LiquidRoundedSuperellipse(borderRadius: 20),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          settings: _hudGlass(blur: 3.0, glow: 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ПРИГОТОВЬТЕСЬ',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'К ПРАКТИКЕ',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      // ── Active ────────────────────────────────────────────────
      case _Phase.active:
        final activeColor = _isInhaling ? _kCyan : _kPurple;
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: LiquidRoundedSuperellipse(borderRadius: 20),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          settings: _hudGlass(blur: 3.0, glow: _isInhaling ? 0.92 : 0.84),
          child: Column(
            children: [
              Text(
                _isInhaling ? 'INHALE' : 'EXHALE',
                style: TextStyle(
                  color: activeColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 5,
                  shadows: [
                    Shadow(
                      color: activeColor.withValues(alpha: 0.70),
                      blurRadius: 12,
                    ),
                  ],
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
          ),
        );

      // ── Retention (breath hold) ───────────────────────────────
      case _Phase.retention:
        final mins = _retentionElapsed ~/ 60;
        final secs = _retentionElapsed % 60;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              shape: LiquidRoundedSuperellipse(borderRadius: 20),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: _hudGlass(blur: 3.5, glow: 0.92),
              child: Stack(
                children: [
                  // Ambient purple bloom absorbed by the glass refraction.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.8, -0.5),
                          radius: 1.1,
                          colors: [
                            _kPurple.withValues(alpha: 0.09),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const Text(
                        'HOLD',
                        style: TextStyle(
                          color: _kPurple,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 5,
                          shadows: [Shadow(color: _kPurple, blurRadius: 10)],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      // Bold monospace timer — high-contrast over the glass.
                      Text(
                        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                          fontFeatures: [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(color: _kPurple, blurRadius: 14),
                            Shadow(color: _kPurple, blurRadius: 42),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'MAX ${_settings.exhaustRetentionSecs ~/ 60}:${(_settings.exhaustRetentionSecs % 60).toString().padLeft(2, '0')}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SieButton(label: 'RELEASE', onPressed: _endRetention),
          ],
        );

      // ── Recovery (inhale hold) ────────────────────────────────
      case _Phase.recovery:
        final recovSecsLeft = _recoveryHoldSecs - _recoveryElapsed;
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: LiquidRoundedSuperellipse(borderRadius: 20),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          settings: _hudGlass(blur: 3.5, glow: 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'HOLD YOUR BREATH',
                style: TextStyle(
                  color: _kCyan,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  shadows: [Shadow(color: _kCyan, blurRadius: 10)],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '(INHALE)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      letterSpacing: 2,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '${recovSecsLeft}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  fontFeatures: [FontFeature.tabularFigures()],
                  shadows: [
                    Shadow(color: _kCyan, blurRadius: 14),
                    Shadow(color: _kCyan, blurRadius: 42),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      // ── Round Transition ──────────────────────────────────────
      case _Phase.roundTransition:
        final secsLeft     = 10 - _transitionElapsed;
        final isFinalRound = _round == _settings.rounds;
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: LiquidRoundedSuperellipse(borderRadius: 20),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          settings: _hudGlass(blur: 3.0, glow: 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFinalRound) ...[
                const Text(
                  'EXHALE',
                  style: TextStyle(
                    color: _kCyan,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 5,
                    shadows: [Shadow(color: _kCyan, blurRadius: 10)],
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  'PREPARE FOR THE',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        letterSpacing: 2,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                const Text(
                  'NEXT ROUND',
                  style: TextStyle(
                    color: _kCyan,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    shadows: [Shadow(color: _kCyan, blurRadius: 10)],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '${secsLeft}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  fontFeatures: [FontFeature.tabularFigures()],
                  shadows: [
                    Shadow(color: _kCyan, blurRadius: 14),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      // ── Complete (spinner while DB write finishes) ────────────
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
  final VoidCallback onInfo;

  const _TopBar({
    required this.phase,
    required this.round,
    required this.totalRounds,
    required this.onBack,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final showRound =
        phase != _Phase.idle && phase != _Phase.countdown && phase != _Phase.complete;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          // Back — glass circle matching the leaderboard back button.
          GestureDetector(
            onTap: onBack,
            child: GlassCard(
              width: 36,
              height: 36,
              padding: EdgeInsets.zero,
              shape: LiquidRoundedSuperellipse(borderRadius: 18),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: _hudGlass(blur: 2.0, glow: 0.85),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: SieTheme.textSecondary,
                  size: 15,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (showRound)
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              shape: LiquidRoundedSuperellipse(borderRadius: 16),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: _hudGlass(blur: 2.5, glow: 0.88),
              child: Text(
                'ROUND $round / $totalRounds',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          const Spacer(),
          // Info — glass circle.
          GestureDetector(
            onTap: onInfo,
            child: GlassCard(
              width: 36,
              height: 36,
              padding: EdgeInsets.zero,
              shape: LiquidRoundedSuperellipse(borderRadius: 18),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              clipBehavior: Clip.antiAlias,
              settings: _hudGlass(blur: 2.0, glow: 0.82),
              child: Center(
                child: Icon(
                  Icons.help_outline,
                  color: SieTheme.textSecondary.withValues(alpha: 0.7),
                  size: 18,
                ),
              ),
            ),
          ),
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
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: LiquidRoundedSuperellipse(borderRadius: 16),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          clipBehavior: Clip.antiAlias,
          settings: _hudGlass(blur: 2.5, glow: 0.84),
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
            max: 7,
            onChanged: (v) => _update(_s.copyWith(exhaleSecs: v)),
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
            onTap: value > min
                ? () => onChanged((value - step).clamp(min, max))
                : null,
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
            onTap: value < max
                ? () => onChanged((value + step).clamp(min, max))
                : null,
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
            border: Border.all(color: _kCyan.withValues(alpha: 0.85), width: 1.0),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kCyan.withValues(alpha: 0.14),
                blurRadius: 24,
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: _kCyan,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              shadows: [Shadow(color: _kCyan, blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}
