import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Ambient fade constants
const _ambientTargetVolume = 0.15;
const _ambientFadeDurationMs = 3000;
const _ambientFadeStepMs = 100;
const _ambientFadeSteps = _ambientFadeDurationMs ~/ _ambientFadeStepMs; // 30

// Cue soft-stop: 490 ms fade-out scheduled before the end of each phase.
// Using 14 steps × 35 ms = exactly 490 ms total.
const _cueFadeMs = 490;
const _cueFadeStepMs = 35;
const _cueFadeSteps = _cueFadeMs ~/ _cueFadeStepMs; // 14
const double _cueVolume = 0.6;

class AudioService {
  final _ambient = AudioPlayer();

  // Separate player for cues with AudioFocus.none — prevents Android from
  // ducking/pausing the ambient track when a cue starts playing.
  final _breathCue = AudioPlayer();

  // Configured once before the first cue play; cached as a Future so the
  // await is a no-op on every subsequent call.
  late final Future<void> _cueReady = _breathCue.setAudioContext(
    AudioContext(
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    ),
  );

  // Fixed asset durations. Rate = assetDuration / targetSeconds → the sound
  // ends precisely when the breathing circle reaches its target position.
  static const double baseInhaleDuration = 5.0;
  static const double baseExhaleDuration = 7.0;

  Timer? _ambientFadeTimer;

  // One variable covers both the initial delay and the periodic fade:
  // first assigned to the delay Timer, then reassigned inside its callback
  // to the Timer.periodic that does the actual fade.
  Timer? _cueFadeTimer;

  double _ambientVolume = 0.0;

  // ── Ambient ────────────────────────────────────────────────

  Future<void> startAmbient() async {
    try {
      _ambientFadeTimer?.cancel();
      _ambientVolume = 0.0;
      await _ambient.setReleaseMode(ReleaseMode.loop);
      await _ambient.play(AssetSource('audio/ambient.mp3'), volume: 0.0);
      _startFadeIn();
    } catch (e) {
      debugPrint('SiE Audio: ambient unavailable — $e');
    }
  }

  void _startFadeIn() {
    _ambientFadeTimer?.cancel();
    var step = 0;
    _ambientFadeTimer = Timer.periodic(
      const Duration(milliseconds: _ambientFadeStepMs),
      (t) {
        step++;
        _ambientVolume = (step / _ambientFadeSteps * _ambientTargetVolume)
            .clamp(0.0, _ambientTargetVolume);
        _ambient.setVolume(_ambientVolume);
        if (step >= _ambientFadeSteps) t.cancel();
      },
    );
  }

  Future<void> _fadeOutAndStop() {
    _ambientFadeTimer?.cancel();
    if (_ambientVolume <= 0.001) return _ambient.stop();

    final completer = Completer<void>();
    final startVolume = _ambientVolume;
    var step = 0;

    _ambientFadeTimer = Timer.periodic(
      const Duration(milliseconds: _ambientFadeStepMs),
      (t) {
        step++;
        _ambientVolume =
            (startVolume - step / _ambientFadeSteps * startVolume)
                .clamp(0.0, 1.0);
        _ambient.setVolume(_ambientVolume);

        if (step >= _ambientFadeSteps || _ambientVolume <= 0.001) {
          t.cancel();
          _ambientVolume = 0.0;
          _ambient
              .stop()
              .whenComplete(() {
                if (!completer.isCompleted) completer.complete();
              })
              .onError((_, _) {
                if (!completer.isCompleted) completer.complete();
              });
        }
      },
    );

    return completer.future;
  }

  // ── Rate ───────────────────────────────────────────────────

  /// Computes rate = baseDuration / [targetSeconds], clamps to [0.5, 2.0],
  /// and applies it to [_breathCue]. Must be called before every play().
  Future<void> setRateForPhase(double targetSeconds, bool isInhale) async {
    final base = isInhale ? baseInhaleDuration : baseExhaleDuration;
    final rate = (base / targetSeconds).clamp(0.5, 2.0);
    await _breathCue.setPlaybackRate(rate);
  }

  // ── Cues ───────────────────────────────────────────────────

  Future<void> playInhale({required int targetSecs}) async {
    _cueFadeTimer?.cancel();
    try {
      await _cueReady;
      await _breathCue.stop();
      await setRateForPhase(targetSecs.toDouble(), true);
      await _breathCue.play(AssetSource('audio/inhale.mp3'), volume: _cueVolume);
      _scheduleCueFadeOut(targetSecs);
    } catch (e) {
      debugPrint('SiE Audio: inhale error — $e');
    }
  }

  Future<void> playExhale({required int targetSecs}) async {
    _cueFadeTimer?.cancel();
    try {
      await _cueReady;
      await _breathCue.stop();
      await setRateForPhase(targetSecs.toDouble(), false);
      await _breathCue.play(AssetSource('audio/exhale.mp3'), volume: _cueVolume);
      _scheduleCueFadeOut(targetSecs);
    } catch (e) {
      debugPrint('SiE Audio: exhale error — $e');
    }
  }

  // Schedules a 350 ms soft-stop at the end of the current phase:
  //   1. Wait (targetSecs × 1000 − 350) ms with a one-shot Timer.
  //   2. Then fade volume from _cueVolume → 0 over 10 × 35 ms steps.
  //   3. Call stop() once volume reaches 0.
  // Dart is single-threaded, so there is no race between the outer timer
  // firing and _cueFadeTimer being reassigned to the inner periodic timer.
  void _scheduleCueFadeOut(int targetSecs) {
    final delayMs = (targetSecs * 1000 - _cueFadeMs).clamp(0, targetSecs * 1000);
    _cueFadeTimer = Timer(Duration(milliseconds: delayMs), () {
      var step = 0;
      _cueFadeTimer = Timer.periodic(
        const Duration(milliseconds: _cueFadeStepMs),
        (t) {
          step++;
          final vol =
              (_cueVolume * (1.0 - step / _cueFadeSteps)).clamp(0.0, _cueVolume);
          _breathCue.setVolume(vol);
          if (step >= _cueFadeSteps) {
            t.cancel();
            _cueFadeTimer = null;
            _breathCue.stop();
          }
        },
      );
    });
  }

  // ── Cleanup ────────────────────────────────────────────────

  /// Cancels the cue fade, fades out ambient over 3 s, stops both players.
  Future<void> stopAll() async {
    _cueFadeTimer?.cancel();
    try {
      await Future.wait([_fadeOutAndStop(), _breathCue.stop()]);
    } catch (_) {}
  }

  Future<void> dispose() async {
    _cueFadeTimer?.cancel();
    _ambientFadeTimer?.cancel();
    try {
      await Future.wait([_ambient.stop(), _breathCue.stop()]);
      await Future.wait([_ambient.dispose(), _breathCue.dispose()]);
    } catch (_) {}
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});
