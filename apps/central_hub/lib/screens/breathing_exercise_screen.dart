import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sie_core/sie_core.dart';
import 'mission_accomplished_screen.dart';

// ── Gold palette ───────────────────────────────────────────────
const _kAmberGold  = Color(0xFFFFBF00);
const _kLightGold  = Color(0xFFFFFACD);

// ── Settings ──────────────────────────────────────────────────

class BreathingSettings {
  final int rounds;
  final int cyclesPerRound;
  final int inhaleSecs;
  final int exhaleSecs;
  final int exhaustRetentionSecs;
  final int recoveryHoldSecs;
  final bool ambientEnabled;
  final bool breathingSoundsEnabled;
  final bool heartbeatEnabled;
  final bool tickEnabled;
  final double ambientVolume;
  final double breathingVolume;
  final double heartbeatVolume;
  final double tickVolume;

  const BreathingSettings({
    this.rounds = 3,
    this.cyclesPerRound = 30,
    this.inhaleSecs = 2,
    this.exhaleSecs = 2,
    this.exhaustRetentionSecs = 90,
    this.recoveryHoldSecs = 15,
    this.ambientEnabled = true,
    this.breathingSoundsEnabled = true,
    this.heartbeatEnabled = true,
    this.tickEnabled = true,
    this.ambientVolume = 0.75,
    this.breathingVolume = 0.75,
    this.heartbeatVolume = 0.75,
    this.tickVolume = 0.75,
  });

  BreathingSettings copyWith({
    int? rounds,
    int? cyclesPerRound,
    int? inhaleSecs,
    int? exhaleSecs,
    int? exhaustRetentionSecs,
    int? recoveryHoldSecs,
    bool? ambientEnabled,
    bool? breathingSoundsEnabled,
    bool? heartbeatEnabled,
    bool? tickEnabled,
    double? ambientVolume,
    double? breathingVolume,
    double? heartbeatVolume,
    double? tickVolume,
  }) =>
      BreathingSettings(
        rounds: rounds ?? this.rounds,
        cyclesPerRound: cyclesPerRound ?? this.cyclesPerRound,
        inhaleSecs: inhaleSecs ?? this.inhaleSecs,
        exhaleSecs: exhaleSecs ?? this.exhaleSecs,
        exhaustRetentionSecs: exhaustRetentionSecs ?? this.exhaustRetentionSecs,
        recoveryHoldSecs: recoveryHoldSecs ?? this.recoveryHoldSecs,
        ambientEnabled: ambientEnabled ?? this.ambientEnabled,
        breathingSoundsEnabled:
            breathingSoundsEnabled ?? this.breathingSoundsEnabled,
        heartbeatEnabled: heartbeatEnabled ?? this.heartbeatEnabled,
        tickEnabled: tickEnabled ?? this.tickEnabled,
        ambientVolume: ambientVolume ?? this.ambientVolume,
        breathingVolume: breathingVolume ?? this.breathingVolume,
        heartbeatVolume: heartbeatVolume ?? this.heartbeatVolume,
        tickVolume: tickVolume ?? this.tickVolume,
      );

  Map<String, dynamic> toJson() => {
        'rounds': rounds,
        'cyclesPerRound': cyclesPerRound,
        'inhaleSecs': inhaleSecs,
        'exhaleSecs': exhaleSecs,
        'exhaustRetentionSecs': exhaustRetentionSecs,
        'recoveryHoldSecs': recoveryHoldSecs,
        'ambientEnabled': ambientEnabled,
        'breathingSoundsEnabled': breathingSoundsEnabled,
        'heartbeatEnabled': heartbeatEnabled,
        'tickEnabled': tickEnabled,
        'ambientVolume': ambientVolume,
        'breathingVolume': breathingVolume,
        'heartbeatVolume': heartbeatVolume,
        'tickVolume': tickVolume,
      };

  factory BreathingSettings.fromJson(Map<String, dynamic> json) =>
      BreathingSettings(
        rounds: (json['rounds'] as int? ?? 3).clamp(1, 10),
        cyclesPerRound: (json['cyclesPerRound'] as int? ?? 30).clamp(5, 60),
        inhaleSecs: (json['inhaleSecs'] as int? ?? 2).clamp(1, 10),
        exhaleSecs: (json['exhaleSecs'] as int? ?? 2).clamp(1, 10),
        exhaustRetentionSecs: (json['exhaustRetentionSecs'] as int? ?? 90).clamp(10, 300),
        recoveryHoldSecs: (json['recoveryHoldSecs'] as int? ?? 15).clamp(5, 60),
        ambientEnabled: json['ambientEnabled'] as bool? ?? true,
        breathingSoundsEnabled: json['breathingSoundsEnabled'] as bool? ?? true,
        heartbeatEnabled: json['heartbeatEnabled'] as bool? ?? true,
        tickEnabled: json['tickEnabled'] as bool? ?? true,
        ambientVolume: ((json['ambientVolume'] as num?)?.toDouble() ?? 0.75).clamp(0.0, 1.0),
        breathingVolume: ((json['breathingVolume'] as num?)?.toDouble() ?? 0.75).clamp(0.0, 1.0),
        heartbeatVolume: ((json['heartbeatVolume'] as num?)?.toDouble() ?? 0.75).clamp(0.0, 1.0),
        tickVolume: ((json['tickVolume'] as num?)?.toDouble() ?? 0.75).clamp(0.0, 1.0),
      );
}

// ── Phase ─────────────────────────────────────────────────────

enum _Phase { idle, countdown, active, retention, recovery, roundTransition, complete }

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
  late final AnimationController _breathColorCtrl;
  late final AnimationController _shaderCtrl;
  late final Animation<double> _pulseAnim;
  late final AudioService _audio;

  FragmentShader? _sphereShader;

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
  Timer? _heartbeatTimer;
  DateTime? _sessionStart;
  DateTime? _heartbeatStart;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    _circleCtrl = AnimationController(vsync: this, value: 0.3);
    _breathColorCtrl = AnimationController(vsync: this, value: 0.0);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _shaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _loadSphereShader();
  }

  Future<void> _loadSphereShader() async {
    try {
      final program = await FragmentProgram.fromAsset(
        'assets/shaders/breathing_sphere.frag',
      );
      if (mounted) setState(() => _sphereShader = program.fragmentShader());
    } catch (_) {
      // Shader unavailable — gradient fallback stays
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    _audio.stopAll();
    _circleCtrl.dispose();
    _breathColorCtrl.dispose();
    _pulseCtrl.dispose();
    _shaderCtrl.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _breathTimer?.cancel();
    _retentionTimer?.cancel();
    _transitionTimer?.cancel();
    _heartbeatTimer?.cancel();
  }

  // ── Back / Partial XP ────────────────────────────────────────

  Future<void> _onBack() async {
    _cancelTimers();
    _audio.stopAll();
    await _awardPartialXpIfEligible();
    if (mounted) Navigator.of(context).pop();
  }

  void _onSphereTap() {
    if (_phase == _Phase.idle) _startSession();
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

  void _restartSession() {
    _cancelTimers();
    _audio.stopAll();
    _heartbeatStart = null;
    _sessionStart = null;
    setState(() {
      _round = 1;
      _cycle = 0;
      _retentionElapsed = 0;
      _recoveryElapsed = 0;
      _transitionElapsed = 0;
    });
    _circleCtrl.stop();
    _breathColorCtrl.stop();
    _pulseCtrl.stop();
    _circleCtrl.value = 0.3;
    _breathColorCtrl.value = 0.0;
    _startCountdown();
  }

  void _startCountdown() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.countdown;
      _countdownValue = 5;
    });
    if (_settings.ambientEnabled) _audio.startAmbient(volumeFactor: _settings.ambientVolume);
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
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
    _breathColorCtrl.value = 0.0;
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
    _breathColorCtrl.animateTo(0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    if (_settings.breathingSoundsEnabled) _audio.playInhale(targetSecs: _settings.inhaleSecs, volumeFactor: _settings.breathingVolume);
    _circleCtrl.animateTo(
      1.0,
      duration: Duration(seconds: _settings.inhaleSecs),
      curve: Curves.easeIn,
    );
    _breathTimer = Timer(Duration(seconds: _settings.inhaleSecs), () {
      if (!mounted || _phase != _Phase.active) return;
      setState(() => _isInhaling = false);
      _breathColorCtrl.animateTo(1.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      if (_settings.breathingSoundsEnabled) _audio.playExhale(targetSecs: _settings.exhaleSecs, volumeFactor: _settings.breathingVolume);
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
    _breathColorCtrl.animateTo(1.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    if (_settings.ambientEnabled) {
      _audio.fadeAmbientTo(0.0);
      _audio.startHum(volumeFactor: _settings.ambientVolume);
    }
    if (_settings.exhaustRetentionSecs <= 30) _startHeartbeatSequence();
    _retentionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final next = _retentionElapsed + 1;
      if (next >= _settings.exhaustRetentionSecs) {
        t.cancel();
        setState(() => _retentionElapsed = next);
        _endRetention();
      } else {
        setState(() => _retentionElapsed = next);
        if (next == _settings.exhaustRetentionSecs - 30) _startHeartbeatSequence();
      }
    });
  }

  void _endRetention() {
    _retentionTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatStart = null;
    _pulseCtrl.stop();
    _startRecoveryPhase();
  }

  void _startHeartbeatSequence() {
    _heartbeatTimer?.cancel();
    _heartbeatStart = DateTime.now();
    _scheduleNextHeartbeat();
  }

  void _scheduleNextHeartbeat() {
    if (_phase != _Phase.retention || _heartbeatStart == null) return;
    if (_settings.heartbeatEnabled) _audio.playHeartbeat(volumeFactor: _settings.heartbeatVolume);
    final elapsedMs = DateTime.now().difference(_heartbeatStart!).inMilliseconds;
    if (elapsedMs >= 30000) return;
    final t = (elapsedMs / 30000).clamp(0.0, 1.0);
    final bpm = 72.0 - 32.0 * t; // 72 BPM → 40 BPM over 30 s
    final intervalMs = (60000 / bpm).round();
    _heartbeatTimer = Timer(Duration(milliseconds: intervalMs), _scheduleNextHeartbeat);
  }

  // ── Phase: Recovery (Hold on Inhale) ─────────────────────

  void _startRecoveryPhase() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.recovery;
      _recoveryElapsed = 0;
    });
    _breathColorCtrl.animateTo(0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    if (_settings.breathingSoundsEnabled) _audio.playInhale(targetSecs: 3, volumeFactor: _settings.breathingVolume);
    _circleCtrl.animateTo(
      1.0,
      duration: const Duration(seconds: 3),
      curve: Curves.easeIn,
    );
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_settings.tickEnabled) _audio.playTick(volumeFactor: _settings.tickVolume);
      final next = _recoveryElapsed + 1;
      setState(() => _recoveryElapsed = next);
      if (next >= _settings.recoveryHoldSecs) {
        t.cancel();
        _startRoundTransitionPhase();
      }
    });
  }

  // ── Phase: Round Transition ───────────────────────────────

  void _startRoundTransitionPhase() {
    if (!mounted) return;
    _audio.stopHum();
    if (_settings.ambientEnabled) {
      _audio.fadeAmbientTo(_settings.ambientVolume);
    }
    _circleCtrl.value = 1.0;
    setState(() {
      _phase = _Phase.roundTransition;
      _transitionElapsed = 0;
    });
    _breathColorCtrl.animateTo(1.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    if (_settings.breathingSoundsEnabled) _audio.playExhale(targetSecs: 5, volumeFactor: _settings.breathingVolume);
    _circleCtrl.animateTo(
      0.3,
      duration: const Duration(seconds: 5),
      curve: Curves.easeOut,
    );
    _transitionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
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

    final stopFuture = _audio.stopAll();
    final dbFuture = ref
        .read(sessionCompletionProvider.notifier)
        .completeSession(durationSeconds: elapsed);

    await stopFuture;
    final result = await dbFuture;

    ref.invalidate(userProfileProvider);

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
  }

  // ── Settings Sheet ────────────────────────────────────────

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
    final c = ref.watch(sieColorsProvider);

    final profile = ref.watch(userProfileProvider).valueOrNull;
    final showOnboarding = _showOnboardingManual ||
        (!_onboardingDismissed &&
            profile != null &&
            !profile.hasSeenOnboardingBreathing);

    return Stack(
      children: [
        SieBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
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
                        scale: (_phase == _Phase.idle && _spherePressed)
                            ? 0.95
                            : 1.0,
                        duration: const Duration(milliseconds: 80),
                        child: _buildCircle(c),
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
                            scale: Tween<double>(begin: 0.7, end: 1.0)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          '$_countdownValue',
                          key: ValueKey(_countdownValue),
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 80,
                            fontWeight: FontWeight.w100,
                            letterSpacing: 4,
                            shadows: c.isLightMode
                                ? null
                                : [
                                    Shadow(color: c.accent, blurRadius: 20),
                                    Shadow(color: c.accent, blurRadius: 60),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 40, left: 32, right: 32,
                    child: _buildBottomArea(c),
                  ),
                ],
              ),
            ),
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
            xpReward: 50,
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

  Widget _buildCircle(SieColors c) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_circleCtrl, _pulseAnim, _breathColorCtrl, _shaderCtrl]),
      builder: (_, _) {
        final t           = _circleCtrl.value;
        final pulse       = (_phase == _Phase.retention) ? _pulseAnim.value : 1.0;
        final colorT      = _breathColorCtrl.value;
        final size        = (130.0 + t * 130.0) * pulse;
        final bool isRetention = _phase == _Phase.retention;

        final double glow = isRetention
            ? 0.70 + (pulse - 0.92) * 3.5
            : (0.55 + t * 0.55) * (1 - colorT) + (0.40 + t * 0.50) * colorT;

        final double rimIntensity = isRetention
            ? (0.7 + (pulse - 0.92) * 4.0).clamp(0.0, 1.0)
            : (0.4 + t * 0.6).clamp(0.0, 1.0);

        final double lightAngle = -pi / 4 + t * 0.4;
        final shaderTime = _shaderCtrl.value * 60.0;

        // Fallback gradient when shader hasn't loaded yet
        final fallbackColors = c.isLightMode
            ? <Color>[const Color(0xFFF1F1F5), const Color(0xFFD0D2DC)]
            : <Color>[const Color(0xFF1C2035), const Color(0xFF2A3048)];

        return Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1 — Outer golden corona
            Container(
              width: size + 60,
              height: size + 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kAmberGold.withValues(
                        alpha: (glow * (c.isLightMode ? 0.18 : 0.30))
                            .clamp(0.0, 1.0)),
                    blurRadius: c.isLightMode ? 45 : 60,
                  ),
                ],
              ),
            ),

            // Layer 2 — Cloud sphere (shader IS the sphere, fully opaque)
            ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: _sphereShader != null
                    ? CustomPaint(
                        painter: _ShaderPainter(
                          shader: _sphereShader!,
                          time: shaderTime,
                          breath: t,
                          sphereSize: size,
                          isDark: !c.isLightMode,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: fallbackColors,
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
              ),
            ),

            // Layer 3 — Golden rim
            CustomPaint(
              size: Size(size, size),
              painter: SphereRimPainter(
                lightAngle: lightAngle,
                intensity: rimIntensity,
                isDark: !c.isLightMode,
              ),
            ),

            // Layer 4 — Inner content
            SizedBox(
              width: size,
              height: size,
              child: switch (_phase) {
                _Phase.idle => Center(
                    child: Icon(
                      Icons.fingerprint,
                      color: c.accent.withValues(alpha: 0.35),
                      size: 36,
                    ),
                  ),
                _Phase.retention => Center(
                    child: Container(
                      width: size * 0.30,
                      height: size * 0.30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _kLightGold.withValues(alpha: 0.25),
                            _kLightGold.withValues(alpha: 0.0),
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

  Widget _buildBottomArea(SieColors c) {
    switch (_phase) {

      // ── Idle ──────────────────────────────────────────────────
      case _Phase.idle:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _hudCard(
              c,
              blur: 3.5,
              glow: 0.90,
              child: Column(
                children: [
                  Text(
                    'WIM HOF METHOD',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_settings.rounds} ROUNDS  ·  ${_settings.cyclesPerRound} CYCLES',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TAP SPHERE TO START',
                    style: TextStyle(
                      color: c.accent.withValues(alpha: 0.55),
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
        return _hudCard(
          c,
          blur: 3.0,
          glow: 0.88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ПРИГОТОВЬТЕСЬ',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'К ПРАКТИКЕ',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      // ── Active ────────────────────────────────────────────────
      case _Phase.active:
        final activeColor = _isInhaling ? c.accent : c.accentSecondary;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _hudCard(
              c,
              blur: 3.0,
              glow: _isInhaling ? 0.92 : 0.84,
              child: Column(
                children: [
                  Text(
                    _isInhaling ? 'INHALE' : 'EXHALE',
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 5,
                      shadows: c.isLightMode
                          ? null
                          : [
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
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _RestartButton(onTap: _restartSession),
          ],
        );

      // ── Retention (breath hold) ───────────────────────────────
      case _Phase.retention:
        final mins = _retentionElapsed ~/ 60;
        final secs = _retentionElapsed % 60;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _hudCard(

              c,
              blur: 3.5,
              glow: 0.92,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'HOLD',
                          style: TextStyle(
                            color: c.accentSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 5,
                            shadows: c.isLightMode
                                ? null
                                : [
                                    Shadow(
                                      color: c.accentSecondary,
                                      blurRadius: 10,
                                    ),
                                  ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 6,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            shadows: c.isLightMode
                                ? null
                                : [
                                    Shadow(
                                      color: c.accentSecondary,
                                      blurRadius: 14,
                                    ),
                                    Shadow(
                                      color: c.accentSecondary,
                                      blurRadius: 42,
                                    ),
                                  ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'MAX ${_settings.exhaustRetentionSecs ~/ 60}:${(_settings.exhaustRetentionSecs % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SieButton(label: 'RELEASE', onPressed: _endRetention),
            const SizedBox(height: 12),
            _RestartButton(onTap: _restartSession),
          ],
        );

      // ── Recovery (inhale hold) ────────────────────────────────
      case _Phase.recovery:
        final recovSecsLeft = _settings.recoveryHoldSecs - _recoveryElapsed;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _hudCard(
              c,
              blur: 3.5,
              glow: 0.92,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'HOLD YOUR BREATH',
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      shadows: c.isLightMode
                          ? null
                          : [Shadow(color: c.accent, blurRadius: 10)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '(INHALE)',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${recovSecsLeft}s',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: c.isLightMode
                          ? null
                          : [
                              Shadow(color: c.accent, blurRadius: 14),
                              Shadow(color: c.accent, blurRadius: 42),
                            ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _RestartButton(onTap: _restartSession),
          ],
        );

      // ── Round Transition ──────────────────────────────────────
      case _Phase.roundTransition:
        final secsLeft     = 10 - _transitionElapsed;
        final isFinalRound = _round == _settings.rounds;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _hudCard(
              c,
              blur: 3.0,
              glow: 0.88,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFinalRound) ...[
                    Text(
                      'EXHALE',
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 5,
                        shadows: c.isLightMode
                            ? null
                            : [Shadow(color: c.accent, blurRadius: 10)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Text(
                      'PREPARE FOR THE',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NEXT ROUND',
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        shadows: c.isLightMode
                            ? null
                            : [Shadow(color: c.accent, blurRadius: 10)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '${secsLeft}s',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: c.isLightMode
                          ? null
                          : [Shadow(color: c.accent, blurRadius: 14)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _RestartButton(onTap: _restartSession),
          ],
        );

      // ── Complete (spinner while DB write finishes) ────────────
      case _Phase.complete:
        return Consumer(
          builder: (_, ref, _) {
            final cc = ref.watch(sieColorsProvider);
            return Center(
              child: CircularProgressIndicator(
                color: cc.accent,
                strokeWidth: 1.5,
              ),
            );
          },
        );
    }
  }

  Widget _hudCard(SieColors c, {double blur = 3.0, double glow = 0.88, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: c.flatCard(radius: 20),
      child: child,
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final showRound = phase != _Phase.idle &&
        phase != _Phase.countdown &&
        phase != _Phase.complete;

    Widget circleBtn(IconData icon, VoidCallback onTap, {double alpha = 1.0}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: c.flatCard(radius: 18),
          child: Center(
            child: Icon(icon, color: c.textSecondary.withValues(alpha: alpha), size: 15),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          circleBtn(Icons.arrow_back_ios_new, onBack),
          const Spacer(),
          if (showRound)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: c.flatCard(radius: 16),
              child: Text(
                'ROUND $round / $totalRounds',
                style: TextStyle(color: c.textSecondary, fontSize: 11, letterSpacing: 1.5),
              ),
            ),
          const Spacer(),
          circleBtn(Icons.help_outline, onInfo, alpha: 0.7),
        ],
      ),
    );
  }
}

// ── Settings Button ───────────────────────────────────────────

class _SettingsButton extends ConsumerWidget {
  final VoidCallback onTap;
  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.tune, size: 20, color: c.textSecondary),
        const SizedBox(width: 10),
        Text(
          'PROTOCOL SETTINGS',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: c.flatCard(radius: 16),
          child: content,
        ),
      ),
    );
  }
}

// ── Settings Sheet ────────────────────────────────────────────

class _SettingsSheet extends ConsumerStatefulWidget {
  final BreathingSettings settings;
  final ValueChanged<BreathingSettings> onChanged;

  const _SettingsSheet({required this.settings, required this.onChanged});

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  late BreathingSettings _s;
  final List<BreathingSettings?> _presets = [null, null, null];

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
    _loadPresetsFromPrefs();
  }

  Future<void> _loadPresetsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = <BreathingSettings?>[];
    for (var i = 1; i <= 3; i++) {
      final jsonStr = prefs.getString('breathing_preset_$i');
      if (jsonStr == null) {
        loaded.add(null);
        continue;
      }
      try {
        loaded.add(BreathingSettings.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>));
      } catch (_) {
        loaded.add(null);
      }
    }
    if (!mounted) return;
    setState(() {
      _presets
        ..[0] = loaded[0]
        ..[1] = loaded[1]
        ..[2] = loaded[2];
    });
  }

  Future<void> _savePreset(int zeroIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'breathing_preset_${zeroIndex + 1}', jsonEncode(_s.toJson()));
    if (!mounted) return;
    setState(() => _presets[zeroIndex] = _s);
  }

  void _loadPreset(int zeroIndex) {
    final p = _presets[zeroIndex];
    if (p != null) _update(p);
  }

  String _presetLabel(BreathingSettings? s) => s == null
      ? 'ПУСТО'
      : '${s.rounds}r · ${s.cyclesPerRound}c · ${s.exhaustRetentionSecs}s';

  void _update(BreathingSettings s) {
    setState(() => _s = s);
    widget.onChanged(s);
  }

  Widget _sectionLabel(BuildContext context, SieColors c, String text) =>
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Text(
          text,
          style: TextStyle(
            color: c.textSecondary.withValues(alpha: 0.55),
            fontSize: 10,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);

    final content = SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: c.isLightMode
                        ? c.border
                        : Colors.white.withValues(alpha: 0.20),
                  ),
                ),
              ),
              Text(
                'PROTOCOL SETTINGS',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: c.textPrimary,
                    ),
              ),
              const SizedBox(height: 16),
              _sectionLabel(context, c, 'PROTOCOL'),
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
                onChanged: (v) =>
                    _update(_s.copyWith(exhaustRetentionSecs: v)),
              ),
              _SettingRow(
                label: 'RECOVERY HOLD (SEC)',
                value: _s.recoveryHoldSecs,
                min: 10,
                max: 30,
                onChanged: (v) => _update(_s.copyWith(recoveryHoldSecs: v)),
              ),
              const SizedBox(height: 12),
              _sectionLabel(context, c, 'SOUND TOGGLES'),
              _ToggleRow(
                label: 'AMBIENT MUSIC',
                value: _s.ambientEnabled,
                onChanged: (v) => _update(_s.copyWith(ambientEnabled: v)),
              ),
              _ToggleRow(
                label: 'BREATHING SOUNDS',
                value: _s.breathingSoundsEnabled,
                onChanged: (v) =>
                    _update(_s.copyWith(breathingSoundsEnabled: v)),
              ),
              _ToggleRow(
                label: 'HEARTBEAT',
                value: _s.heartbeatEnabled,
                onChanged: (v) => _update(_s.copyWith(heartbeatEnabled: v)),
              ),
              _ToggleRow(
                label: 'CLOCK TICKS',
                value: _s.tickEnabled,
                onChanged: (v) => _update(_s.copyWith(tickEnabled: v)),
              ),
              const SizedBox(height: 12),
              _sectionLabel(context, c, 'VOLUME'),
              _VolumeRow(
                label: 'AMBIENT MUSIC',
                value: _s.ambientVolume,
                onChanged: (v) => _update(_s.copyWith(ambientVolume: v)),
              ),
              _VolumeRow(
                label: 'BREATHING',
                value: _s.breathingVolume,
                onChanged: (v) => _update(_s.copyWith(breathingVolume: v)),
              ),
              _VolumeRow(
                label: 'HEARTBEAT',
                value: _s.heartbeatVolume,
                onChanged: (v) => _update(_s.copyWith(heartbeatVolume: v)),
              ),
              _VolumeRow(
                label: 'CLOCK TICKS',
                value: _s.tickVolume,
                onChanged: (v) => _update(_s.copyWith(tickVolume: v)),
              ),
              const SizedBox(height: 12),
              _sectionLabel(context, c, 'PRESETS'),
              const SizedBox(height: 4),
              for (var i = 0; i < 3; i++)
                _PresetRow(
                  slot: i + 1,
                  label: _presetLabel(_presets[i]),
                  hasData: _presets[i] != null,
                  onLoad: _presets[i] != null ? () => _loadPreset(i) : null,
                  onSave: () => _savePreset(i),
                ),
            ],
          ),
        ),
      ),
    );

    final decoration = BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      color: c.surface,
      border: Border(top: BorderSide(color: c.border, width: 1.0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(decoration: decoration, child: content),
    );
  }
}

class _SettingRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
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
              style: TextStyle(
                color: c.textPrimary,
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

class _ToggleRow extends ConsumerWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: c.accent),
        ],
      ),
    );
  }
}

class _VolumeRow extends ConsumerWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _VolumeRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: c.accent,
                thumbColor: c.accent,
                inactiveTrackColor: c.border,
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(color: c.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetRow extends ConsumerWidget {
  final int slot;
  final String label;
  final bool hasData;
  final VoidCallback? onLoad;
  final VoidCallback onSave;

  const _PresetRow({
    required this.slot,
    required this.label,
    required this.hasData,
    this.onLoad,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: c.accent.withValues(alpha: 0.50)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '$slot',
                style: TextStyle(color: c.accent, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: hasData ? c.textPrimary : c.textSecondary.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          ),
          if (onLoad != null) ...[
            _PresetBtn(label: 'LOAD', onTap: onLoad!, c: c),
            const SizedBox(width: 8),
          ],
          _PresetBtn(label: 'SAVE', onTap: onSave, c: c, isPrimary: true),
        ],
      ),
    );
  }
}

class _PresetBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final SieColors c;
  final bool isPrimary;

  const _PresetBtn({
    required this.label,
    required this.onTap,
    required this.c,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
            color: isPrimary ? c.accent.withValues(alpha: 0.70) : c.border,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPrimary ? c.accent : c.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _StepBtn extends ConsumerStatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, required this.active, this.onTap});

  @override
  ConsumerState<_StepBtn> createState() => _StepBtnState();
}

class _StepBtnState extends ConsumerState<_StepBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(sieColorsProvider);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 220),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.active
                  ? _pressed
                      ? c.accent
                      : c.accent.withValues(alpha: 0.65)
                  : c.border,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(4),
            color: widget.active && _pressed
                ? c.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            boxShadow: widget.active && !c.isLightMode
                ? [
                    BoxShadow(
                      color: c.accent.withValues(
                        alpha: _pressed ? 0.28 : 0.10,
                      ),
                      blurRadius: _pressed ? 10 : 6,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: widget.active ? c.accent : c.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Restart Button ────────────────────────────────────────────

class _RestartButton extends ConsumerWidget {
  final VoidCallback onTap;
  const _RestartButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'НАЧАТЬ ЗАНОВО',
            style: TextStyle(
              color: c.textSecondary.withValues(alpha: 0.55),
              fontSize: 11,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared Button ─────────────────────────────────────────────

class _SieButton extends ConsumerWidget {
  final String label;
  final VoidCallback onPressed;

  const _SieButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sieColorsProvider);
    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: c.accent.withValues(alpha: 0.85),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: c.isLightMode
                ? null
                : [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.14),
                      blurRadius: 24,
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: c.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              shadows: c.isLightMode
                  ? null
                  : [Shadow(color: c.accent, blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}

// ── SphereRimPainter ────────────────────────────────────────────
class SphereRimPainter extends CustomPainter {
  final double lightAngle;
  final double intensity;
  final bool isDark;

  const SphereRimPainter({
    required this.lightAngle,
    required this.intensity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.0;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    // Solid gold ring — clean and uniform like the reference
    final rimPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color       = const Color(0xFFC8A84B).withValues(
          alpha: (0.80 + intensity * 0.20).clamp(0.0, 1.0));
    canvas.drawCircle(center, radius, rimPaint);

    // Subtle metallic highlight arc at top-left
    final highlightPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color       = _kLightGold.withValues(
          alpha: (0.25 + intensity * 0.25).clamp(0.0, 0.55))
      ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawArc(rect, lightAngle - pi * 0.5 - 0.5, 1.2, false, highlightPaint);
  }

  @override
  bool shouldRepaint(SphereRimPainter old) =>
      lightAngle != old.lightAngle || intensity != old.intensity;
}

// ── _ShaderPainter ──────────────────────────────────────────────
class _ShaderPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;
  final double breath;
  final double sphereSize;
  final bool isDark;

  _ShaderPainter({
    required this.shader,
    required this.time,
    required this.breath,
    required this.sphereSize,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      shader.setFloat(0, time);
      shader.setFloat(1, breath);
      shader.setFloat(2, size.width);
      shader.setFloat(3, size.height);
      shader.setFloat(4, isDark ? 1.0 : 0.0);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } catch (_) {
      // Stale cached shader — graceful no-op until next clean build
    }
  }

  @override
  bool shouldRepaint(_ShaderPainter old) =>
      time != old.time ||
      breath != old.breath ||
      sphereSize != old.sphereSize ||
      isDark != old.isDark;
}
