import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Optional planning context for a focus session (Stage 7). When present, the
/// completed session's time is attributed to this task/goal.
typedef FocusTaskRef = ({
  String taskId,
  String subGoalId,
  String goalId,
  String taskTitle,
});

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
  // Stage 7: planning context bound to the current session (null = free focus).
  final FocusTaskRef? taskRef;

  const FocusTimerState({
    this.settings = const FocusSettings(),
    this.phase = FocusPhase.idle,
    this.secondsRemaining = 25 * 60,
    this.isRunning = false,
    this.completedSessions = 0,
    this.totalDurationSecs = 25 * 60,
    this.pendingResult,
    this.taskRef,
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
    Object? taskRef = _omit,
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
        taskRef: identical(taskRef, _omit)
            ? this.taskRef
            : taskRef as FocusTaskRef?,
      );
}

// ── Persistence keys ──────────────────────────────────────────

const _kFocusPhase           = 'focus_phase';
const _kFocusPhaseStartMs    = 'focus_phase_start_ms';
const _kFocusSecsRemaining   = 'focus_secs_remaining';
const _kFocusIsRunning       = 'focus_is_running';
const _kFocusTotalDurSecs    = 'focus_total_duration_secs';
const _kFocusWorkMinutes     = 'focus_work_minutes';
const _kFocusBreakMinutes    = 'focus_break_minutes';
const _kFocusWorkMusic       = 'focus_work_music_enabled';
const _kFocusBreakMusic      = 'focus_break_music_enabled';
const _kFocusCompletedSess   = 'focus_completed_sessions';
const _kFocusTaskId          = 'focus_task_id';
const _kFocusSubGoalId       = 'focus_sub_goal_id';
const _kFocusGoalId          = 'focus_goal_id';
const _kFocusTaskTitle       = 'focus_task_title';

// ── Notifier ──────────────────────────────────────────────────

class FocusTimerNotifier extends Notifier<FocusTimerState> {
  Timer? _ticker;
  DateTime? _phaseStartedAt;

  // Tracks whether ambient is currently active so start() can decide
  // whether to (re-)start it without reaching into AudioService internals.
  bool _ambientActive = false;

  @override
  FocusTimerState build() {
    Future.microtask(_restoreFromPrefs);
    return const FocusTimerState();
  }

  Future<void> _restoreFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final phaseStr = prefs.getString(_kFocusPhase);
    if (phaseStr == null) return;

    final phase = phaseStr == 'work' ? FocusPhase.work : FocusPhase.breakTime;
    final totalDurSecs   = prefs.getInt(_kFocusTotalDurSecs)   ?? 25 * 60;
    final workMinutes    = prefs.getInt(_kFocusWorkMinutes)     ?? 25;
    final breakMinutes   = prefs.getInt(_kFocusBreakMinutes)    ?? 5;
    final workMusic      = prefs.getBool(_kFocusWorkMusic)      ?? true;
    final breakMusic     = prefs.getBool(_kFocusBreakMusic)     ?? true;
    final completedSess  = prefs.getInt(_kFocusCompletedSess)   ?? 0;
    final wasRunning     = prefs.getBool(_kFocusIsRunning)      ?? false;

    int remaining;
    if (wasRunning) {
      final phaseStartMs = prefs.getInt(_kFocusPhaseStartMs);
      if (phaseStartMs != null) {
        final phaseStart = DateTime.fromMillisecondsSinceEpoch(phaseStartMs);
        final elapsed = DateTime.now().difference(phaseStart).inSeconds;
        remaining = (totalDurSecs - elapsed).clamp(0, totalDurSecs);
      } else {
        remaining = prefs.getInt(_kFocusSecsRemaining) ?? totalDurSecs;
      }
    } else {
      remaining = prefs.getInt(_kFocusSecsRemaining) ?? totalDurSecs;
    }

    if (remaining <= 0) {
      await _clearSession();
      return;
    }

    final settings = FocusSettings(
      workMinutes: workMinutes,
      breakMinutes: breakMinutes,
      isWorkMusicEnabled: workMusic,
      isBreakMusicEnabled: breakMusic,
    );

    final taskId = prefs.getString(_kFocusTaskId);
    final subGoalId = prefs.getString(_kFocusSubGoalId);
    final goalId = prefs.getString(_kFocusGoalId);
    final taskTitle = prefs.getString(_kFocusTaskTitle);
    final restoredRef = (taskId != null && subGoalId != null && goalId != null)
        ? (
            taskId: taskId,
            subGoalId: subGoalId,
            goalId: goalId,
            taskTitle: taskTitle ?? '',
          )
        : null;

    state = FocusTimerState(
      settings: settings,
      phase: phase,
      secondsRemaining: remaining,
      isRunning: false,
      completedSessions: completedSess,
      totalDurationSecs: totalDurSecs,
      taskRef: restoredRef,
    );
  }

  Future<void> _saveSession() async {
    if (state.phase == FocusPhase.idle) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFocusPhase,
        state.phase == FocusPhase.work ? 'work' : 'break');
    await prefs.setInt(_kFocusTotalDurSecs, state.totalDurationSecs);
    await prefs.setInt(_kFocusSecsRemaining, state.secondsRemaining);
    await prefs.setBool(_kFocusIsRunning, state.isRunning);
    await prefs.setInt(_kFocusWorkMinutes, state.settings.workMinutes);
    await prefs.setInt(_kFocusBreakMinutes, state.settings.breakMinutes);
    await prefs.setBool(_kFocusWorkMusic, state.settings.isWorkMusicEnabled);
    await prefs.setBool(_kFocusBreakMusic, state.settings.isBreakMusicEnabled);
    await prefs.setInt(_kFocusCompletedSess, state.completedSessions);
    final ref_ = state.taskRef;
    if (ref_ != null) {
      await prefs.setString(_kFocusTaskId, ref_.taskId);
      await prefs.setString(_kFocusSubGoalId, ref_.subGoalId);
      await prefs.setString(_kFocusGoalId, ref_.goalId);
      await prefs.setString(_kFocusTaskTitle, ref_.taskTitle);
    } else {
      await prefs.remove(_kFocusTaskId);
      await prefs.remove(_kFocusSubGoalId);
      await prefs.remove(_kFocusGoalId);
      await prefs.remove(_kFocusTaskTitle);
    }
    if (state.isRunning && _phaseStartedAt != null) {
      await prefs.setInt(
          _kFocusPhaseStartMs, _phaseStartedAt!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_kFocusPhaseStartMs);
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kFocusPhase, _kFocusPhaseStartMs, _kFocusSecsRemaining,
      _kFocusIsRunning, _kFocusTotalDurSecs, _kFocusWorkMinutes,
      _kFocusBreakMinutes, _kFocusWorkMusic, _kFocusBreakMusic,
      _kFocusCompletedSess, _kFocusTaskId, _kFocusSubGoalId, _kFocusGoalId,
      _kFocusTaskTitle,
    ]) {
      await prefs.remove(key);
    }
  }

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

  void start({FocusTaskRef? taskRef}) {
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
        // A fresh start adopts the provided binding (or clears a stale one).
        taskRef: taskRef,
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
    _saveSession();
  }

  void pause() {
    if (!state.isRunning) return;
    _ticker?.cancel();
    state = state.copyWith(isRunning: false);
    // Ambient is intentionally left playing during pause so the user can
    // return to the session without an abrupt silence.
    _saveSession();
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
    _clearSession();
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
      final boundRef = state.taskRef;
      final result = await _saveWorkSession(settings: settings);
      state = FocusTimerState(
        settings: settings,
        phase: FocusPhase.breakTime,
        secondsRemaining: settings.breakSecs,
        isRunning: false,
        completedSessions: completedSessions + 1,
        totalDurationSecs: settings.breakSecs,
        pendingResult: result,
        // Keep the binding through the break so the result overlay can offer
        // "mark task done" and the header keeps showing context.
        taskRef: boundRef,
      );
      _phaseStartedAt = null;
      _saveSession();
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
      _clearSession();
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
    // Capture planning binding before any async gap (Stage 7).
    final taskRef = state.taskRef;

    // Always record locally.
    await db.insertFocusSession(LocalFocusSessionsCompanion(
      id: Value(sessionId),
      userId: Value(userId),
      durationSeconds: Value(settings.workSecs),
      completedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
      xpAwarded: const Value(_focusXp),
      dpAwarded: const Value(_focusDp),
      synced: Value(isOnline),
      taskId: Value(taskRef?.taskId),
      goalId: Value(taskRef?.goalId),
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
          if (taskRef != null) 'task_id': taskRef.taskId,
          if (taskRef != null) 'goal_id': taskRef.goalId,
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
