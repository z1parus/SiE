import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundpool/soundpool.dart';
import 'web_audio_helper.dart';

// ── Ambient fade constants ─────────────────────────────────────
const _ambientTargetVolume = 0.15;
const _ambientFadeDurationMs = 3000;
const _ambientFadeStepMs = 100;
const _ambientFadeSteps = _ambientFadeDurationMs ~/ _ambientFadeStepMs; // 30

// ── Cue soft-stop: 490 ms fade-out before end of each phase ───
const _cueFadeMs = 490;
const _cueFadeStepMs = 35;
const _cueFadeSteps = _cueFadeMs ~/ _cueFadeStepMs; // 14
const double _cueVolume = 0.6;

class AudioService {
  // ── Ambient — AudioPlayer on all platforms (looping long audio) ─
  final _ambient = AudioPlayer();
  Timer? _ambientFadeTimer;
  double _ambientVolume = 0.0;

  // ── Short cues — Soundpool on all platforms ─────────────────
  // soundpool_web backs this with Web Audio API (AudioBufferSourceNode)
  // which has near-zero latency vs the <audio>-element path in audioplayers.
  // SoundPool on Android/iOS also decodes PCM into RAM for instant play.
  //
  // soundpool.play() has no volume parameter; call setVolume() after play().
  // Stream IDs are 1-based; 0 means play() failed.
  final _pool = Soundpool.fromOptions(
    options: const SoundpoolOptions(streamType: StreamType.music, maxStreams: 4),
  );
  int _inhaleId = -1, _exhaleId = -1, _chimeId = -1;
  int _inhaleStream = 0, _exhaleStream = 0;

  bool _initialized = false;
  Timer? _cueFadeTimer;

  static const double baseInhaleDuration = 5.0;
  static const double baseExhaleDuration = 7.0;

  // ── Init ────────────────────────────────────────────────────

  /// Web: must be called from inside a user-gesture handler. The overlay calls
  ///      [unlockWebAudio()] synchronously (before any await) in the same tap,
  ///      which creates and resumes a dart:html AudioContext, establishing the
  ///      user-activation needed for soundpool_web's AudioContext to start
  ///      in 'running' state when [load()] creates it here.
  ///
  /// Native: called automatically by [audioServiceProvider]; loads assets into
  ///         SoundPool's PCM buffer and warms up the iOS audio pipeline.
  ///
  /// Safe to call multiple times; only executes once.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final results = await Future.wait([
        _pool.load(await rootBundle.load('assets/audio/inhale.mp3')),
        _pool.load(await rootBundle.load('assets/audio/exhale.mp3')),
        _pool.load(await rootBundle.load('assets/audio/notification_end.mp3')),
      ]);
      _inhaleId = results[0];
      _exhaleId = results[1];
      _chimeId = results[2];

      // Web: listen for page visibility changes so we can recover after
      // the browser suspends audio on screen-lock or tab-switch.
      // On native the OS manages audio sessions; this is a no-op stub.
      setupVisibilityListener(_onPageVisible);

      // iOS native warm-up: AVAudioEngine needs at least one play() before the
      // first real sound to prime its internal buffer pipeline.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final streams = await Future.wait([
          _pool.play(_inhaleId),
          _pool.play(_exhaleId),
          _pool.play(_chimeId),
        ]);
        for (final s in streams) {
          if (s > 0) _pool.stop(s).ignore();
        }
      }
    } catch (e) {
      debugPrint('SiE Audio: init error — $e');
    }
  }

  // Called by the visibility listener when the page returns from background.
  void _onPageVisible() {
    if (_ambientVolume > 0.001) {
      // Attempt soft resume; if the <audio> element was fully stopped by the
      // browser, fall back to a clean restart.
      _ambient.resume().catchError((_) => startAmbient());
    }
  }

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

  Future<void> stopAmbient() => _fadeOutAndStop();

  // ── Rate helper ────────────────────────────────────────────

  double _rateFor(double targetSeconds, bool isInhale) {
    final base = isInhale ? baseInhaleDuration : baseExhaleDuration;
    return (base / targetSeconds).clamp(0.5, 2.0);
  }

  // ── Cues ───────────────────────────────────────────────────

  Future<void> playInhale({required int targetSecs}) async {
    _cueFadeTimer?.cancel();
    if (_inhaleId < 0) return;
    try {
      _stopStream(_exhaleStream);
      _stopStream(_inhaleStream);
      _inhaleStream = await _pool.play(_inhaleId, rate: _rateFor(targetSecs.toDouble(), true));
      await _applyVolume(_inhaleId, _inhaleStream, _cueVolume);
      final sid = _inhaleStream;
      final iid = _inhaleId;
      _scheduleCueFadeOut(
        targetSecs,
        (v) { if (sid > 0) _pool.setVolume(soundId: iid, streamId: sid, volume: v).ignore(); },
        () { _stopStream(sid); },
      );
    } catch (e) {
      debugPrint('SiE Audio: inhale error — $e');
    }
  }

  Future<void> playExhale({required int targetSecs}) async {
    _cueFadeTimer?.cancel();
    if (_exhaleId < 0) return;
    try {
      _stopStream(_inhaleStream);
      _stopStream(_exhaleStream);
      _exhaleStream = await _pool.play(_exhaleId, rate: _rateFor(targetSecs.toDouble(), false));
      await _applyVolume(_exhaleId, _exhaleStream, _cueVolume);
      final sid = _exhaleStream;
      final eid = _exhaleId;
      _scheduleCueFadeOut(
        targetSecs,
        (v) { if (sid > 0) _pool.setVolume(soundId: eid, streamId: sid, volume: v).ignore(); },
        () { _stopStream(sid); },
      );
    } catch (e) {
      debugPrint('SiE Audio: exhale error — $e');
    }
  }

  Future<void> _applyVolume(int soundId, int streamId, double volume) async {
    if (streamId > 0) {
      await _pool.setVolume(soundId: soundId, streamId: streamId, volume: volume);
    }
  }

  void _stopStream(int streamId) {
    if (streamId > 0) _pool.stop(streamId).ignore();
  }

  // Soft-stop via callbacks so the same fade logic works for every cue.
  void _scheduleCueFadeOut(
    int targetSecs,
    void Function(double volume) setVol,
    void Function() stop,
  ) {
    final delayMs = (targetSecs * 1000 - _cueFadeMs).clamp(0, targetSecs * 1000);
    _cueFadeTimer = Timer(Duration(milliseconds: delayMs), () {
      var step = 0;
      _cueFadeTimer = Timer.periodic(
        const Duration(milliseconds: _cueFadeStepMs),
        (t) {
          step++;
          final vol = (_cueVolume * (1.0 - step / _cueFadeSteps)).clamp(0.0, _cueVolume);
          try { setVol(vol); } catch (_) {}
          if (step >= _cueFadeSteps) {
            t.cancel();
            _cueFadeTimer = null;
            try { stop(); } catch (_) {}
          }
        },
      );
    });
  }

  // ── Chime ──────────────────────────────────────────────────

  Future<void> playPurchase() async {
    if (_chimeId < 0) return;
    try {
      final sid = await _pool.play(_chimeId, rate: 1.3);
      await _applyVolume(_chimeId, sid, 0.9);
    } catch (e) {
      debugPrint('SiE Audio: purchase sound error — $e');
    }
  }

  Future<void> playPhaseTransition() async {
    if (_chimeId < 0) return;
    try {
      final sid = await _pool.play(_chimeId, rate: 1.0);
      await _applyVolume(_chimeId, sid, 0.85);
    } catch (_) {
      // Fallback: pitch up inhale as chime
      if (_inhaleId >= 0) {
        try {
          final sid = await _pool.play(_inhaleId, rate: 2.0);
          await _applyVolume(_inhaleId, sid, 0.85);
        } catch (e) {
          debugPrint('SiE Audio: phase transition error — $e');
        }
      }
    }
  }

  // ── Cleanup ────────────────────────────────────────────────

  Future<void> stopAll() async {
    _cueFadeTimer?.cancel();
    try {
      await Future.wait([
        _fadeOutAndStop(),
        if (_inhaleStream > 0) _pool.stop(_inhaleStream),
        if (_exhaleStream > 0) _pool.stop(_exhaleStream),
      ]);
    } catch (_) {}
  }

  Future<void> dispose() async {
    _cueFadeTimer?.cancel();
    _ambientFadeTimer?.cancel();
    try {
      await _ambient.stop();
      await _ambient.dispose();
      _pool.dispose();
    } catch (_) {}
  }
}

// Tracks whether AudioService.init() has been called this session.
// Web: set to true by AudioInitOverlay on first user-gesture tap.
// Native: set to true automatically by the provider below.
final audioInitializedProvider = StateProvider<bool>((_) => false);

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  if (!kIsWeb) {
    service.init().whenComplete(() {
      try { ref.read(audioInitializedProvider.notifier).state = true; } catch (_) {}
    });
  }
  ref.onDispose(service.dispose);
  return service;
});
