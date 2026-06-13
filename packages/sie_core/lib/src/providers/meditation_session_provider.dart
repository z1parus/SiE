import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/meditation_preset.dart';
import '../models/affirmation_pack.dart';
import '../services/audio_service.dart';
import 'connectivity_provider.dart';
import 'user_profile_provider.dart';

const _uuid = Uuid();
const _sentinel = Object();

// ── Phases ────────────────────────────────────────────────────────────────────

enum MeditationPhase { idle, breathing, transition, meditating, reflectionPause, complete }

enum BreathingSubPhase { inhale, holdIn, exhale, holdOut }

// ── Breathing pattern definitions (durations in seconds) ─────────────────────

typedef _SubPhaseSpec = (int seconds, BreathingSubPhase subPhase);

const Map<String, List<_SubPhaseSpec>> _breathingPatterns = {
  'box': [
    (4, BreathingSubPhase.inhale),
    (4, BreathingSubPhase.holdIn),
    (4, BreathingSubPhase.exhale),
    (4, BreathingSubPhase.holdOut),
  ],
  '4-7-8': [
    (4, BreathingSubPhase.inhale),
    (7, BreathingSubPhase.holdIn),
    (8, BreathingSubPhase.exhale),
  ],
  'coherence': [
    (5, BreathingSubPhase.inhale),
    (5, BreathingSubPhase.exhale),
  ],
};

// ── Result ────────────────────────────────────────────────────────────────────

class MeditationSessionResult {
  final int xpGained;
  final int dpGained;

  const MeditationSessionResult({required this.xpGained, required this.dpGained});
}

// ── State ─────────────────────────────────────────────────────────────────────

class MeditationSessionState {
  final MeditationPreset? preset;
  final AffirmationPack? affirmationPack;
  final MeditationPhase phase;
  final BreathingSubPhase breathingSubPhase;
  final int breathingSubPhaseRemaining;
  final int breathingElapsedSecs;
  final int meditationElapsedSecs;
  final int totalTargetSecs;
  final bool isRunning;
  final double musicVolume;
  final double ambientVolume;
  final double voiceVolume;
  final bool isMixerVisible;
  final bool isDarkScreenMode;
  final String? currentAffirmation;
  final int? stateBefore;
  final MeditationSessionResult? completionResult;

  const MeditationSessionState({
    this.preset,
    this.affirmationPack,
    this.phase = MeditationPhase.idle,
    this.breathingSubPhase = BreathingSubPhase.inhale,
    this.breathingSubPhaseRemaining = 0,
    this.breathingElapsedSecs = 0,
    this.meditationElapsedSecs = 0,
    this.totalTargetSecs = 0,
    this.isRunning = false,
    this.musicVolume = 0.7,
    this.ambientVolume = 0.5,
    this.voiceVolume = 0.6,
    this.isMixerVisible = false,
    this.isDarkScreenMode = false,
    this.currentAffirmation,
    this.stateBefore,
    this.completionResult,
  });

  double get overallProgress => totalTargetSecs > 0
      ? (breathingElapsedSecs + meditationElapsedSecs) / totalTargetSecs
      : 0.0;

  int get remainingSeconds =>
      totalTargetSecs - breathingElapsedSecs - meditationElapsedSecs;

  String get formattedRemaining {
    final secs = remainingSeconds.clamp(0, totalTargetSecs);
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  MeditationSessionState copyWith({
    Object? preset = _sentinel,
    Object? affirmationPack = _sentinel,
    MeditationPhase? phase,
    BreathingSubPhase? breathingSubPhase,
    int? breathingSubPhaseRemaining,
    int? breathingElapsedSecs,
    int? meditationElapsedSecs,
    int? totalTargetSecs,
    bool? isRunning,
    double? musicVolume,
    double? ambientVolume,
    double? voiceVolume,
    bool? isMixerVisible,
    bool? isDarkScreenMode,
    Object? currentAffirmation = _sentinel,
    Object? stateBefore = _sentinel,
    Object? completionResult = _sentinel,
  }) =>
      MeditationSessionState(
        preset: identical(preset, _sentinel) ? this.preset : preset as MeditationPreset?,
        affirmationPack: identical(affirmationPack, _sentinel)
            ? this.affirmationPack
            : affirmationPack as AffirmationPack?,
        phase: phase ?? this.phase,
        breathingSubPhase: breathingSubPhase ?? this.breathingSubPhase,
        breathingSubPhaseRemaining:
            breathingSubPhaseRemaining ?? this.breathingSubPhaseRemaining,
        breathingElapsedSecs: breathingElapsedSecs ?? this.breathingElapsedSecs,
        meditationElapsedSecs:
            meditationElapsedSecs ?? this.meditationElapsedSecs,
        totalTargetSecs: totalTargetSecs ?? this.totalTargetSecs,
        isRunning: isRunning ?? this.isRunning,
        musicVolume: musicVolume ?? this.musicVolume,
        ambientVolume: ambientVolume ?? this.ambientVolume,
        voiceVolume: voiceVolume ?? this.voiceVolume,
        isMixerVisible: isMixerVisible ?? this.isMixerVisible,
        isDarkScreenMode: isDarkScreenMode ?? this.isDarkScreenMode,
        currentAffirmation: identical(currentAffirmation, _sentinel)
            ? this.currentAffirmation
            : currentAffirmation as String?,
        stateBefore: identical(stateBefore, _sentinel)
            ? this.stateBefore
            : stateBefore as int?,
        completionResult: identical(completionResult, _sentinel)
            ? this.completionResult
            : completionResult as MeditationSessionResult?,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MeditationSessionNotifier extends Notifier<MeditationSessionState> {
  Timer? _ticker;
  Timer? _transitionTimer;
  Timer? _mixerHideTimer;

  AudioService get _audio => ref.read(audioServiceProvider);
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  MeditationSessionState build() => const MeditationSessionState();

  void startSession(MeditationPreset preset,
      {AffirmationPack? affirmationPack, int? stateBefore}) {
    _cancelTimers();

    final breathingTargetSecs = preset.hasBreathing
        ? preset.breathingDurationMin * 60
        : 0;
    final meditationTargetSecs = preset.meditationDurationMin * 60;
    final totalSecs = breathingTargetSecs + meditationTargetSecs;

    final initialPhase =
        preset.hasBreathing ? MeditationPhase.breathing : MeditationPhase.meditating;

    state = MeditationSessionState(
      preset: preset,
      affirmationPack: affirmationPack,
      phase: initialPhase,
      breathingSubPhase: BreathingSubPhase.inhale,
      breathingSubPhaseRemaining: _firstSubPhaseDuration(preset),
      totalTargetSecs: totalSecs,
      isRunning: true,
      musicVolume: preset.baseVolume,
      ambientVolume: preset.ambientVolume,
      voiceVolume: preset.voiceVolume,
      stateBefore: stateBefore,
    );

    // Start audio
    _audio.startAmbient(volumeFactor: preset.baseVolume);
    if (preset.ambientFxId != null) {
      _audio.startHum(volumeFactor: preset.ambientVolume);
    }

    // Play first breathing cue
    if (initialPhase == MeditationPhase.breathing) {
      _playBreathingCue(BreathingSubPhase.inhale,
          _firstSubPhaseDuration(preset), preset);
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void pause() {
    if (!state.isRunning) return;
    _cancelTimers();
    state = state.copyWith(isRunning: false);
    _audio.stopAmbient();
    _audio.stopHum();
  }

  void resume() {
    if (state.isRunning || state.phase == MeditationPhase.idle) return;
    state = state.copyWith(isRunning: true);
    _audio.startAmbient(volumeFactor: state.musicVolume);
    if (state.preset?.ambientFxId != null) {
      _audio.startHum(volumeFactor: state.ambientVolume);
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void abandonSession() {
    _cancelTimers();
    final elapsed = state.breathingElapsedSecs + state.meditationElapsedSecs;
    if (elapsed >= 60) {
      _saveSession(elapsed, null);
    }
    _audio.stopAll();
    state = const MeditationSessionState();
  }

  void completeSession(int stateAfter) {
    _cancelTimers();
    _audio.stopAll();
    final elapsed = state.breathingElapsedSecs + state.meditationElapsedSecs;
    _saveSession(elapsed, stateAfter);
  }

  void setMixerVisible(bool visible) {
    state = state.copyWith(isMixerVisible: visible);
  }

  void scheduleMixerHide() {
    _mixerHideTimer?.cancel();
    _mixerHideTimer = Timer(const Duration(seconds: 5), () {
      state = state.copyWith(isMixerVisible: false);
    });
  }

  void updateVolume({double? music, double? ambient, double? voice}) {
    if (music != null) {
      state = state.copyWith(musicVolume: music);
      _audio.fadeAmbientTo(music, durationMs: 200);
    }
    if (ambient != null) {
      state = state.copyWith(ambientVolume: ambient);
      _audio.fadeHumTo(ambient, durationMs: 200);
    }
    if (voice != null) {
      state = state.copyWith(voiceVolume: voice);
    }
  }

  void toggleDarkScreenMode() {
    state = state.copyWith(isDarkScreenMode: !state.isDarkScreenMode);
  }

  // ── Internal tick ─────────────────────────────────────────────────────────

  void _onTick() {
    if (!state.isRunning) return;
    switch (state.phase) {
      case MeditationPhase.breathing:
        _breathingTick();
      case MeditationPhase.meditating:
        _meditationTick();
      default:
        break;
    }
  }

  void _breathingTick() {
    final preset = state.preset;
    if (preset == null) return;

    final newSubRemaining = state.breathingSubPhaseRemaining - 1;
    final newElapsed = state.breathingElapsedSecs + 1;
    final breathingTarget = preset.breathingDurationMin * 60;

    if (newElapsed >= breathingTarget) {
      // Breathing phase complete
      state = state.copyWith(
        breathingElapsedSecs: breathingTarget,
        breathingSubPhaseRemaining: 0,
      );
      _startTransition();
      return;
    }

    if (newSubRemaining <= 0) {
      // Advance to next sub-phase
      final nextSpec = _nextSubPhase(state.breathingSubPhase, preset);
      state = state.copyWith(
        breathingElapsedSecs: newElapsed,
        breathingSubPhase: nextSpec.$2,
        breathingSubPhaseRemaining: nextSpec.$1,
      );
      _playBreathingCue(nextSpec.$2, nextSpec.$1, preset);
    } else {
      state = state.copyWith(
        breathingElapsedSecs: newElapsed,
        breathingSubPhaseRemaining: newSubRemaining,
      );
    }
  }

  void _meditationTick() {
    final preset = state.preset;
    if (preset == null) return;

    final newElapsed = state.meditationElapsedSecs + 1;
    final meditationTarget = preset.meditationDurationMin * 60;

    // Rotate affirmation
    _checkAffirmation(newElapsed, preset);

    if (newElapsed >= meditationTarget) {
      state = state.copyWith(
        meditationElapsedSecs: meditationTarget,
        phase: MeditationPhase.reflectionPause,
        isRunning: false,
      );
      _cancelTimers();
      _audio.stopAll();
      return;
    }

    state = state.copyWith(meditationElapsedSecs: newElapsed);
  }

  void _checkAffirmation(int newElapsed, MeditationPreset preset) {
    final pack = state.affirmationPack;
    if (pack == null || pack.phrases.isEmpty) return;
    if (preset.meditationType != 'affirmations') return;

    final interval = preset.affirmationIntervalSecs;
    if (newElapsed % interval == 0 && newElapsed > 0) {
      final idx = (newElapsed ~/ interval) % pack.phrases.length;
      state = state.copyWith(currentAffirmation: pack.phrases[idx]);
    }
  }

  void _startTransition() {
    state = state.copyWith(
      phase: MeditationPhase.transition,
    );

    // Audio crossfade
    _audio.playPhaseTransition();
    _audio.fadeAmbientTo(state.ambientVolume, durationMs: 3000);

    _transitionTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      state = state.copyWith(phase: MeditationPhase.meditating);
      // Show first affirmation at session start
      final pack = state.affirmationPack;
      if (pack != null && pack.phrases.isNotEmpty &&
          state.preset?.meditationType == 'affirmations') {
        state = state.copyWith(currentAffirmation: pack.phrases[0]);
      }
    });
  }

  bool get mounted {
    try {
      // ignore: unused_local_variable
      final _ = state;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Save session ──────────────────────────────────────────────────────────

  Future<void> _saveSession(int durationSeconds, int? stateAfter) async {
    final preset = state.preset;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final id = _uuid.v4();
    final now = DateTime.now();

    // Save locally first
    await _db.insertMeditationSession(LocalMeditationSessionsCompanion(
      id: Value(id),
      userId: Value(userId),
      presetId: Value(preset?.id),
      durationSeconds: Value(durationSeconds),
      completedAtMs: Value(now.millisecondsSinceEpoch),
      xpAwarded: const Value(0),
      dpAwarded: const Value(0),
      stateBefore: Value(state.stateBefore),
      stateAfter: Value(stateAfter),
      synced: const Value(false),
    ));

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    int xp = (durationSeconds ~/ 60) * 5;
    int dp = durationSeconds ~/ 120;

    if (isOnline) {
      try {
        final result = await Supabase.instance.client.rpc(
          'log_meditation_session',
          params: {
            'p_preset_id': preset?.id,
            'p_duration_seconds': durationSeconds,
            'p_state_before': state.stateBefore,
            'p_state_after': stateAfter,
          },
        );
        if (result is List && result.isNotEmpty) {
          xp = (result[0]['xp_awarded'] as num?)?.toInt() ?? xp;
          dp = (result[0]['dp_awarded'] as num?)?.toInt() ?? dp;
        }
        await _db.markMeditationSessionSynced(id);
      } catch (e) {
        debugPrint('MeditationSession: sync error — $e');
      }
    }

    // Apply XP locally
    try {
      ref.read(userProfileProvider.notifier).applyLocalXpDelta(xp, dp);
    } catch (_) {}

    state = state.copyWith(
      phase: MeditationPhase.complete,
      completionResult: MeditationSessionResult(xpGained: xp, dpGained: dp),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _firstSubPhaseDuration(MeditationPreset preset) {
    final pattern = _breathingPatterns[preset.breathingPatternId ?? 'box'];
    if (pattern == null || pattern.isEmpty) return 4;
    return pattern[0].$1;
  }

  _SubPhaseSpec _nextSubPhase(
      BreathingSubPhase current, MeditationPreset preset) {
    final pattern =
        _breathingPatterns[preset.breathingPatternId ?? 'box'] ?? _breathingPatterns['box']!;

    final currentIdx = pattern.indexWhere((s) => s.$2 == current);
    final nextIdx = (currentIdx + 1) % pattern.length;
    return pattern[nextIdx];
  }

  void _playBreathingCue(
      BreathingSubPhase sub, int durationSecs, MeditationPreset preset) {
    if (durationSecs <= 0) return;
    switch (sub) {
      case BreathingSubPhase.inhale:
        _audio.playInhale(
            targetSecs: durationSecs, volumeFactor: preset.baseVolume);
      case BreathingSubPhase.exhale:
        _audio.playExhale(
            targetSecs: durationSecs, volumeFactor: preset.baseVolume);
      default:
        break; // holdIn / holdOut: no audio cue
    }
  }

  void _cancelTimers() {
    _ticker?.cancel();
    _ticker = null;
    _transitionTimer?.cancel();
    _transitionTimer = null;
    _mixerHideTimer?.cancel();
    _mixerHideTimer = null;
  }

}

final meditationSessionProvider =
    NotifierProvider<MeditationSessionNotifier, MeditationSessionState>(
  MeditationSessionNotifier.new,
);
