import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundpool/soundpool.dart';
import 'web_audio_helper.dart';

// ── Ambient fade constants ─────────────────────────────────────
const _ambientMaxVolume      = 0.20;  // 100% volume; default 75% → 0.15
const _ambientFadeDurationMs = 3000;
const _ambientFadeStepMs     = 100;
const _ambientFadeSteps      = _ambientFadeDurationMs ~/ _ambientFadeStepMs; // 30

// ── Cue soft-stop: 490 ms fade-out before end of each phase ───
const _cueFadeMs    = 490;
const _cueFadeStepMs = 35;
const _cueFadeSteps  = _cueFadeMs ~/ _cueFadeStepMs; // 14

// ── Volume maximums (at volumeFactor = 1.0; default 0.75 = current behaviour) ─
const _cueMaxVolume       = 0.80;   // 0.60 / 0.75
const _heartbeatMaxVolume = 0.73;   // 0.55 / 0.75
const _tickMaxVolume      = 0.29;   // 0.22 / 0.75

class AudioService {
  // ── Ambient — AudioPlayer on all platforms (looping long audio) ─
  final _ambient = AudioPlayer();
  Timer? _ambientFadeTimer;
  double _ambientVolume = 0.0;
  double _ambientFadeTarget = _ambientMaxVolume * 0.75; // = 0.15, default

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
          _pool.play(_inhaleId,    volumeLeft: 0, volumeRight: 0),
          _pool.play(_exhaleId,    volumeLeft: 0, volumeRight: 0),
          _pool.play(_chimeId,     volumeLeft: 0, volumeRight: 0),
          _pool.play(_heartbeatId, volumeLeft: 0, volumeRight: 0),
          _pool.play(_tickId,      volumeLeft: 0, volumeRight: 0),
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

  Future<void> startAmbient({double volumeFactor = 0.75}) async {
    try {
      _ambientFadeTimer?.cancel();
      _ambientVolume = 0.0;
      _ambientFadeTarget = (_ambientMaxVolume * volumeFactor).clamp(0.0, 1.0);
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
        _ambientVolume = (step / _ambientFadeSteps * _ambientFadeTarget)
            .clamp(0.0, _ambientFadeTarget);
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

  Future<void> playInhale({required int targetSecs, double volumeFactor = 0.75}) async {
    _cueFadeTimer?.cancel();
    if (_inhaleId < 0) return;
    try {
      _stopStream(_exhaleStream);
      _stopStream(_inhaleStream);
      final vol = (_cueMaxVolume * volumeFactor).clamp(0.0, 1.0);
      _inhaleStream = await _pool.play(_inhaleId, rate: _rateFor(targetSecs.toDouble(), true));
      await _applyVolume(_inhaleId, _inhaleStream, vol);
      final sid = _inhaleStream;
      final iid = _inhaleId;
      _scheduleCueFadeOut(
        targetSecs, vol,
        (v) { if (sid > 0) _pool.setVolume(soundId: iid, streamId: sid, volume: v).ignore(); },
        () { _stopStream(sid); },
      );
    } catch (e) {
      debugPrint('SiE Audio: inhale error — $e');
    }
  }

  Future<void> playExhale({required int targetSecs, double volumeFactor = 0.75}) async {
    _cueFadeTimer?.cancel();
    if (_exhaleId < 0) return;
    try {
      _stopStream(_inhaleStream);
      _stopStream(_exhaleStream);
      final vol = (_cueMaxVolume * volumeFactor).clamp(0.0, 1.0);
      _exhaleStream = await _pool.play(_exhaleId, rate: _rateFor(targetSecs.toDouble(), false));
      await _applyVolume(_exhaleId, _exhaleStream, vol);
      final sid = _exhaleStream;
      final eid = _exhaleId;
      _scheduleCueFadeOut(
        targetSecs, vol,
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
    double startVolume,
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
          final vol = (startVolume * (1.0 - step / _cueFadeSteps)).clamp(0.0, startVolume);
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

  Future<void> playHeartbeat({double volumeFactor = 0.75}) async {
    if (_heartbeatId < 0) return;
    try {
      final sid = await _pool.play(_heartbeatId);
      if (sid > 0) {
        await _pool.setVolume(
          soundId: _heartbeatId, streamId: sid,
          volume: (_heartbeatMaxVolume * volumeFactor).clamp(0.0, 1.0),
        );
      }
    } catch (e) {
      debugPrint('SiE Audio: heartbeat error — $e');
    }
  }

  Future<void> playTick({double volumeFactor = 0.75}) async {
    if (_tickId < 0) return;
    try {
      final sid = await _pool.play(_tickId);
      if (sid > 0) {
        await _pool.setVolume(
          soundId: _tickId, streamId: sid,
          volume: (_tickMaxVolume * volumeFactor).clamp(0.0, 1.0),
        );
      }
    } catch (e) {
      debugPrint('SiE Audio: tick error — $e');
    }
  }

  // ── WAV synthesis ─────────────────────────────────────────

  static List<double> _applyEcho(
    List<double> samples, {
    int delayMs = 80,
    double gain = 0.22,
    int sr = 44100,
  }) {
    final delaySamples = sr * delayMs ~/ 1000;
    final tailSamples  = delaySamples + sr * 60 ~/ 1000;
    final extended = List<double>.of(samples)
      ..addAll(List<double>.filled(tailSamples, 0.0));
    for (var i = delaySamples; i < extended.length; i++) {
      final src = i - delaySamples;
      if (src < samples.length) extended[i] += samples[src] * gain;
    }
    return extended;
  }

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

  // Lub-dub heartbeat: deeper tone (45/90/180 Hz), longer decay, with echo
  static Uint8List _generateHeartbeat({int sr = 44100}) {
    const lubMs = 90, gapMs = 75, dubMs = 70, tailMs = 80;
    final n = sr * (lubMs + gapMs + dubMs + tailMs) ~/ 1000;
    final raw = List<double>.filled(n, 0.0);
    final nLub    = sr * lubMs ~/ 1000;
    final nGap    = sr * gapMs ~/ 1000;
    final nDub    = sr * dubMs ~/ 1000;
    final attackN = sr * 5 ~/ 1000; // 5 ms linear attack

    for (var i = 0; i < nLub; i++) {
      final t = i / sr;
      final attack = i < attackN ? i / attackN : 1.0;
      final env    = attack * math.exp(-i / (sr * 0.048));
      raw[i] = env * (math.sin(2 * math.pi * 45  * t) * 0.60 +
                      math.sin(2 * math.pi * 90  * t) * 0.28 +
                      math.sin(2 * math.pi * 180 * t) * 0.12);
    }

    final dubStart = nLub + nGap;
    for (var i = 0; i < nDub; i++) {
      final t = i / sr;
      final attack = i < attackN ? i / attackN : 1.0;
      final env    = attack * math.exp(-i / (sr * 0.040)) * 0.6;
      raw[dubStart + i] = env * (math.sin(2 * math.pi * 50  * t) * 0.60 +
                                  math.sin(2 * math.pi * 100 * t) * 0.28 +
                                  math.sin(2 * math.pi * 200 * t) * 0.12);
    }

    final lubFadeN = sr * 12 ~/ 1000;
    for (var i = 0; i < lubFadeN; i++) {
      final w = 0.5 * (1 + math.cos(math.pi * i / (lubFadeN - 1)));
      raw[nLub - lubFadeN + i] *= w;
    }

    final dubFadeN = sr * 12 ~/ 1000;
    for (var i = 0; i < dubFadeN; i++) {
      final w = 0.5 * (1 + math.cos(math.pi * i / (dubFadeN - 1)));
      raw[dubStart + nDub - dubFadeN + i] *= w;
    }

    return _buildWav(_applyEcho(raw, delayMs: 70, gain: 0.44, sr: sr), sr: sr);
  }

  // Light hi-hat: inharmonic metallic partials (4.8–13 kHz), fast click + sizzle tail
  static Uint8List _generateTick({int sr = 44100}) {
    const durationMs = 90;
    final n             = sr * durationMs ~/ 1000;
    final attackSamples = sr ~/ 4000; // 0.25 ms attack
    const freqs = [4800.0, 5670.0, 6100.0, 7100.0, 8350.0, 9800.0, 11200.0, 13100.0];
    const amps  = [0.22,   0.18,   0.09,   0.16,   0.13,   0.10,   0.07,    0.05  ];
    final raw = List<double>.generate(n, (i) {
      final t      = i / sr;
      final attack = i < attackSamples ? i / attackSamples : 1.0;
      final env    = attack * (math.exp(-i / (sr * 0.007)) * 0.65 +  // τ=7ms  click
                               math.exp(-i / (sr * 0.028)) * 0.35);  // τ=28ms sizzle
      var s = 0.0;
      for (var j = 0; j < freqs.length; j++) {
        s += math.sin(2 * math.pi * freqs[j] * t) * amps[j];
      }
      return env * s;
    });
    return _buildWav(_applyEcho(raw, delayMs: 25, gain: 0.36, sr: sr), sr: sr);
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
