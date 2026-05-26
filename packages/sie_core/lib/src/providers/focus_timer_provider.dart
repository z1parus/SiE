import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import '../local/app_database.dart';
import '../models/achievement.dart';
import '../services/audio_service.dart';
import 'connectivity_provider.dart';
import 'user_profile_provider.dart';

const _focusXp = 100;
const _focusDp = 50;
const _omit = Object();
const _uuid = Uuid();

typedef FocusSessionResult = ({int xpGained, int dpGained, Achievement? newAchievement});

enum FocusPhase { idle, work, breakTime }

// ── Settings ──────────────────────────────────────────────────

class FocusSettings {
  final int workMinutes;
  final int breakMinutes;
  final bool isWorkMusicEnabled;
  final bool isBreakMusicEnabled;

  const FocusSettings({
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.isWorkMusicEnabled = true,
    this.isBreakMusicEnabled = true,
  });

  int get workSecs => workMinutes * 60;
  int get breakSecs => breakMinutes * 60;

  FocusSettings copyWith({
    int? workMinutes,
    int? breakMinutes,
    bool? isWorkMusicEnabled,
    bool? isBreakMusicEnabled,
  }) =>
      FocusSettings(
        workMinutes: workMinutes ?? this.workMinutes,
        breakMinutes: breakMinutes ?? this.breakMinutes,
        isWorkMusicEnabled: isWorkMusicEnabled ?? this.isWorkMusicEnabled,
        isBreakMusicEnabled: isBreakMusicEnabled ?? this.isBreakMusicEnabled,
      );
}

// ── State ─────────────────────────────────────────────────────

class FocusTimerState {
  final FocusSettings settings;
  final FocusPhase phase;
  final int secondsRemaining;
  final bool isRunning;
  final int completedSessions;
  final int totalDurationSecs;
  final FocusSessionResult? pendingResult;

  const FocusTimerState({
    this.settings = const FocusSettings(),
    this.phase = FocusPhase.idle,
    this.secondsRemaining = 25 * 60,
    this.isRunning = false,
    this.completedSessions = 0,
    this.totalDurationSecs = 25 * 60,
    this.pendingResult,
  });

  double get progress => totalDurationSecs > 0
      ? 1.0 - (secondsRemaining / totalDurationSecs)
      : 0.0;

  String get formattedTime {
    final m = secondsRemaining ~/ 60;
    final s = secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  FocusTimerState copyWith({
    FocusSettings? settings,
    FocusPhase? phase,
    int? secondsRemaining,
    bool? isRunning,
    int? completedSessions,
    int? totalDurationSecs,
    Object? pendingResult = _omit,
  }) =>
      FocusTimerState(
        settings: settings ?? this.settings,
        phase: phase ?? this.phase,
        secondsRemaining: secondsRemaining ?? this.secondsRemaining,
        isRunning: isRunning ?? this.isRunning,
        completedSessions: completedSessions ?? this.completedSessions,
        totalDurationSecs: totalDurationSecs ?? this.totalDurationSecs,
        pendingResult: identical(pendingResult, _omit)
            ? this.pendingResult
            : pendingResult as FocusSessionResult?,
      );
}

// ── Notifier ──────────────────────────────────────────────────

class FocusTimerNotifier extends Notifier<FocusTimerState> {
  Timer? _ticker;
  DateTime? _phaseStartedAt;

  // Tracks whether ambient is currently active so start() can decide
  // whether to (re-)start it without reaching into AudioService internals.
  bool _ambientActive = false;

  @override
  FocusTimerState build() => const FocusTimerState();

  void updateSettings(FocusSettings newSettings) {
    if (state.phase == FocusPhase.idle) {
      state = FocusTimerState(
        settings: newSettings,
        completedSessions: state.completedSessions,
        secondsRemaining: newSettings.workSecs,
        totalDurationSecs: newSettings.workSecs,
      );
      return;
    }

    // Session active (running or paused): duration is locked, only music
    // flags may change. Determine which flag governs the current phase.
    final wasMusic = state.phase == FocusPhase.work
        ? state.settings.isWorkMusicEnabled
        : state.settings.isBreakMusicEnabled;
    final willBeMusic = state.phase == FocusPhase.work
        ? newSettings.isWorkMusicEnabled
        : newSettings.isBreakMusicEnabled;

    state = state.copyWith(
      settings: state.settings.copyWith(
        isWorkMusicEnabled: newSettings.isWorkMusicEnabled,
        isBreakMusicEnabled: newSettings.isBreakMusicEnabled,
      ),
    );

    if (wasMusic == willBeMusic) return;

    final audio = ref.read(audioServiceProvider);
    if (willBeMusic) {
      audio.startAmbient();
      _ambientActive = true;
    } else {
      audio.stopAmbient();
      _ambientActive = false;
    }
  }

  void start() {
    if (state.isRunning) return;
    final audio = ref.read(audioServiceProvider);

    if (state.phase == FocusPhase.idle) {
      // Fresh start: idle → work. No transition chime here; it fires at 00:00.
      state = FocusTimerState(
        settings: state.settings,
        phase: FocusPhase.work,
        secondsRemaining: state.settings.workSecs,
        isRunning: true,
        completedSessions: state.completedSessions,
        totalDurationSecs: state.settings.workSecs,
      );
      if (state.settings.isWorkMusicEnabled) {
        audio.startAmbient();
        _ambientActive = true;
      }
    } else if (state.phase == FocusPhase.breakTime && !_ambientActive) {
      // Starting break after phase boundary (ambient was stopped at 00:00).
      state = state.copyWith(isRunning: true);
      if (state.settings.isBreakMusicEnabled) {
        audio.startAmbient();
        _ambientActive = true;
      }
    } else {
      // Resuming a paused work or break session.
      // Ambient state is unchanged — it was either already playing or off.
      state = state.copyWith(isRunning: true);
    }

    _phaseStartedAt = DateTime.now().subtract(
      Duration(seconds: state.totalDurationSecs - state.secondsRemaining),
    );
    _startTicker();
  }

  void pause() {
    if (!state.isRunning) return;
    _ticker?.cancel();
    state = state.copyWith(isRunning: false);
    // Ambient is intentionally left playing during pause so the user can
    // return to the session without an abrupt silence.
  }

  void reset() {
    _ticker?.cancel();
    _phaseStartedAt = null;
    _ambientActive = false;
    ref.read(audioServiceProvider).stopAll();
    state = FocusTimerState(
      settings: state.settings,
      secondsRemaining: state.settings.workSecs,
      totalDurationSecs: state.settings.workSecs,
    );
  }

  void clearResult() {
    state = state.copyWith(pendingResult: null);
  }

  // Called when the app returns from background: corrects remaining time
  // using wall-clock elapsed time.
  void handleForeground() {
    if (!state.isRunning || _phaseStartedAt == null) return;
    _ticker?.cancel();
    final elapsed = DateTime.now().difference(_phaseStartedAt!).inSeconds;
    final remaining =
        (state.totalDurationSecs - elapsed).clamp(0, state.totalDurationSecs);
    if (remaining <= 0) {
      state = state.copyWith(secondsRemaining: 0, isRunning: false);
      _onPhaseComplete();
    } else {
      state = state.copyWith(secondsRemaining: remaining);
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (state.secondsRemaining <= 1) {
      _ticker?.cancel();
      state = state.copyWith(secondsRemaining: 0, isRunning: false);
      _onPhaseComplete();
    } else {
      state = state.copyWith(secondsRemaining: state.secondsRemaining - 1);
    }
  }

  Future<void> _onPhaseComplete() async {
    // Capture mutable fields before the async gap.
    final settings = state.settings;
    final completedSessions = state.completedSessions;
    final audio = ref.read(audioServiceProvider);

    // Chime fires at exactly 00:00 for both phases.
    audio.playPhaseTransition();
    // Ambient fades out gracefully at every phase boundary.
    audio.stopAmbient();
    _ambientActive = false;

    if (state.phase == FocusPhase.work) {
      final result = await _saveWorkSession(settings: settings);
      state = FocusTimerState(
        settings: settings,
        phase: FocusPhase.breakTime,
        secondsRemaining: settings.breakSecs,
        isRunning: false,
        completedSessions: completedSessions + 1,
        totalDurationSecs: settings.breakSecs,
        pendingResult: result,
      );
      _phaseStartedAt = null;
    } else if (state.phase == FocusPhase.breakTime) {
      state = FocusTimerState(
        settings: settings,
        phase: FocusPhase.work,
        secondsRemaining: settings.workSecs,
        isRunning: false,
        completedSessions: completedSessions,
        totalDurationSecs: settings.workSecs,
      );
      _phaseStartedAt = null;
    }
  }

  Future<FocusSessionResult> _saveWorkSession({
    required FocusSettings settings,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return (xpGained: 0, dpGained: 0, newAchievement: null);

    final isOnline = ref.read(connectivityProvider).valueOrNull ?? false;
    final db = ref.read(appDatabaseProvider);
    final sessionId = _uuid.v4();

    // Always record locally.
    await db.insertFocusSession(LocalFocusSessionsCompanion(
      id: Value(sessionId),
      userId: Value(userId),
      durationSeconds: Value(settings.workSecs),
      completedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      xpAwarded: const Value(_focusXp),
      dpAwarded: const Value(_focusDp),
      synced: Value(isOnline),
    ));

    Achievement? earned;

    try {
      if (isOnline) {
        await client.from('focus_sessions').insert({
          'id': sessionId,
          'user_id': userId,
          'duration_seconds': settings.workSecs,
          'is_completed': true,
          'xp_gained': _focusXp,
        });

        await Future.wait([
          client.rpc('increment_xp', params: {
            'p_user_id': userId,
            'p_amount': _focusXp,
          }),
          client.rpc('add_design_points', params: {'p_amount': _focusDp}),
        ]);

        final achRow = await client
            .from('achievements')
            .select()
            .eq('slug', 'deep_focus_initiated')
            .maybeSingle();

        if (achRow != null) {
          final alreadyHas = await client
              .from('user_achievements')
              .select('id')
              .eq('user_id', userId)
              .eq('achievement_id', achRow['id'] as String)
              .maybeSingle();

          if (alreadyHas == null) {
            await client.from('user_achievements').insert({
              'user_id': userId,
              'achievement_id': achRow['id'],
            });
            earned = Achievement.fromMap(achRow);
          }
        }
      }

      // Apply local XP delta for immediate UI update.
      await ref
          .read(userProfileProvider.notifier)
          .applyLocalXpDelta(_focusXp, _focusDp);

      return (
        xpGained: _focusXp,
        dpGained: _focusDp,
        newAchievement: earned
      );
    } catch (e) {
      debugPrint('SiE FocusTimer: save error — $e');
      // Still apply local delta so UI is not stuck.
      await ref
          .read(userProfileProvider.notifier)
          .applyLocalXpDelta(_focusXp, _focusDp);
      return (
        xpGained: _focusXp,
        dpGained: _focusDp,
        newAchievement: null
      );
    }
  }
}

final focusTimerProvider =
    NotifierProvider<FocusTimerNotifier, FocusTimerState>(
  FocusTimerNotifier.new,
);
