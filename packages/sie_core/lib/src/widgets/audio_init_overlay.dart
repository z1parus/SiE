import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_service.dart';
import '../services/web_audio_helper.dart';
import '../theme/sie_theme.dart';

/// Renders a full-screen overlay on top of its parent Stack on web only.
/// On the first tap, calls [AudioService.init()] to unlock the browser
/// AudioContext, then dismisses itself for the rest of the session.
/// On native platforms this widget is a transparent no-op.
class AudioInitOverlay extends ConsumerStatefulWidget {
  const AudioInitOverlay({super.key});

  @override
  ConsumerState<AudioInitOverlay> createState() => _AudioInitOverlayState();
}

class _AudioInitOverlayState extends ConsumerState<AudioInitOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_tapped) return;
    setState(() => _tapped = true);
    // Synchronous: creates a dart:html AudioContext and plays a 1-sample buffer
    // before any await — the only window iOS Safari accepts for audio unlock.
    unlockWebAudio();
    // Async: loads all cue assets into soundpool_web's AudioBufferSourceNode pool.
    // By this point the user-gesture window is established, so soundpool_web's
    // AudioContext starts in 'running' state when created inside load().
    await ref.read(audioServiceProvider).init();
    if (mounted) {
      ref.read(audioInitializedProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final initialized = ref.watch(audioInitializedProvider);
    if (initialized) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Container(
        color: SieTheme.background.withValues(alpha: 0.93),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: SieTheme.accent,
                size: 44,
              ),
              const SizedBox(height: 20),
              const Text(
                'АУДИОСИСТЕМА',
                style: TextStyle(
                  color: SieTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'НЕ ИНИЦИАЛИЗИРОВАНА',
                style: TextStyle(
                  color: SieTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 28),
              _tapped
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: SieTheme.accent,
                        strokeWidth: 1.5,
                      ),
                    )
                  : FadeTransition(
                      opacity: _blink,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: SieTheme.accent),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'НАЖМИТЕ ДЛЯ АКТИВАЦИИ',
                          style: TextStyle(
                            color: SieTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
