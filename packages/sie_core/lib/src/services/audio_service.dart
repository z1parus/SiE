import 'dart:async';
import 'dart:math' as math;

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
    options: const SoundpoolOptions(streamType: StreamType.music, maxStreams: 6),
  );
  int _inhaleId = -1, _exhaleId = -1, _chimeId = -1;
  int _heartbeatId = -1, _tickId = -1;
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
      _heartbeatId = await _pool.load(_generateHeartbeat().buffer.asByteData());
      _tickId      = await _pool.load(_generateTick().buffer.asByteData());

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
          _pool.play(_heartbeatId),
          _pool.play(_tickId),
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

  // ── Heartbeat & Tick ──────────────────────────────────────

  Future<void> playHeartbeat() async {
    if (_heartbeatId < 0) return;
    try {
      final sid = await _pool.play(_heartbeatId);
      if (sid > 0) await _pool.setVolume(soundId: _heartbeatId, streamId: sid, volume: 0.55);
    } catch (e) {
      debugPrint('SiE Audio: heartbeat error — $e');
    }
  }

  Future<void> playTick() async {
    if (_tickId < 0) return;
    try {
      final sid = await _pool.play(_tickId);
      if (sid > 0) await _pool.setVolume(soundId: _tickId, streamId: sid, volume: 0.45);
    } catch (e) {
      debugPrint('SiE Audio: tick error — $e');
    }
  }

  // ── WAV synthesis ─────────────────────────────────────────

  static Uint8List _buildWav(List<double> samples, {int sr = 44100}) {
    double maxA = 0;
    for (final s in samples) {
      final a = s.abs();
      if (a > maxA) maxA = a;
    }
    final scale = maxA > 0 ? 0.95 / maxA : 1.0;

    final dataSize = samples.length * 2;
    final buf = ByteData(44 + dataSize);
    var o = 0;

    void text(String t) { for (final code in t.codeUnits) { buf.setUint8(o++, code); } }
    void u16(int v) { buf.setUint16(o, v, Endian.little); o += 2; }
    void u32(int v) { buf.setUint32(o, v, Endian.little); o += 4; }

    text('RIFF'); u32(36 + dataSize); text('WAVE');
    text('fmt '); u32(16); u16(1); u16(1); u32(sr); u32(sr * 2); u16(2); u16(16);
    text('data'); u32(dataSize);

    for (final s in samples) {
      final v = (s * scale * 32767).round().clamp(-32768, 32767);
      buf.setInt16(o, v, Endian.little);
      o += 2;
    }

    return buf.buffer.asUint8List();
  }

  // Lub-dub heartbeat: lub(80ms) + gap(80ms) + dub(60ms) + tail(80ms)
  static Uint8List _generateHeartbeat({int sr = 44100}) {
    const lubMs = 80, gapMs = 80, dubMs = 60, tailMs = 80;
    final totalSamples = sr * (lubMs + gapMs + dubMs + tailMs) ~/ 1000;
    final samples = List<double>.filled(totalSamples, 0.0);

    final nLub = sr * lubMs ~/ 1000;
    final nGap = sr * gapMs ~/ 1000;
    final nDub = sr * dubMs ~/ 1000;
    final attackN = sr * 4 ~/ 1000; // 4 ms linear attack

    for (var i = 0; i < nLub; i++) {
      final t = i / sr;
      final attack = i < attackN ? i / attackN : 1.0;
      final env = attack * math.exp(-i / (sr * 0.035));
      samples[i] = env * (math.sin(2 * math.pi * 60 * t) * 0.60 +
                          math.sin(2 * math.pi * 120 * t) * 0.28 +
                          math.sin(2 * math.pi * 250 * t) * 0.12);
    }

    final dubStart = nLub + nGap;
    for (var i = 0; i < nDub; i++) {
      final t = i / sr;
      final attack = i < attackN ? i / attackN : 1.0;
      final env = attack * math.exp(-i / (sr * 0.028)) * 0.6;
      samples[dubStart + i] = env * (math.sin(2 * math.pi * 65 * t) * 0.60 +
                                     math.sin(2 * math.pi * 130 * t) * 0.28 +
                                     math.sin(2 * math.pi * 260 * t) * 0.12);
    }

    return _buildWav(samples, sr: sr);
  }

  // Short clock tick: ~35 ms high-freq click with fast exponential decay
  static Uint8List _generateTick({int sr = 44100}) {
    const durationMs = 35;
    final n = sr * durationMs ~/ 1000;
    final attackN = sr * 1 ~/ 1000; // 1 ms attack
    final samples = List<double>.generate(n, (i) {
      final t = i / sr;
      final attack = i < attackN ? i / attackN : 1.0;
      final env = attack * math.exp(-i / (sr * 0.008));
      return env * (math.sin(2 * math.pi * 3000 * t) * 0.55 +
                    math.sin(2 * math.pi * 6000 * t) * 0.35 +
                    math.sin(2 * math.pi * 1200 * t) * 0.10);
    });
    return _buildWav(samples, sr: sr);
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
