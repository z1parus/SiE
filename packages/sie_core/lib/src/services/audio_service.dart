import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Asset durations are fixed — playback rate adapts to user's target duration.
const _inhaleAssetSecs = 5.0;
const _exhaleAssetSecs = 7.0;

class AudioService {
  final _ambient = AudioPlayer();
  final _cue = AudioPlayer();

  Future<void> startAmbient() async {
    try {
      await _ambient.setReleaseMode(ReleaseMode.loop);
      await _ambient.play(AssetSource('audio/ambient.mp3'), volume: 0.25);
    } catch (e) {
      debugPrint('SiE Audio: ambient unavailable — $e');
    }
  }

  /// Rate = assetDuration / targetDuration, clamped to [0.5, 2.0].
  Future<void> playInhale({int targetSecs = 5}) async {
    try {
      final rate = (_inhaleAssetSecs / targetSecs).clamp(0.5, 2.0);
      await _cue.setPlaybackRate(rate);
      await _cue.play(AssetSource('audio/inhale.mp3'), volume: 0.6);
    } catch (_) {}
  }

  Future<void> playExhale({int targetSecs = 7}) async {
    try {
      final rate = (_exhaleAssetSecs / targetSecs).clamp(0.5, 2.0);
      await _cue.setPlaybackRate(rate);
      await _cue.play(AssetSource('audio/exhale.mp3'), volume: 0.6);
    } catch (_) {}
  }

  Future<void> stopAll() async {
    try {
      await _ambient.stop();
      await _cue.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stopAll();
    await _ambient.dispose();
    await _cue.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});
