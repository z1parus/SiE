// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

web.AudioContext? _ctx;
bool _listenerSetup = false;

/// Must be called SYNCHRONOUSLY inside a user-gesture handler (onTap/onClick)
/// before any await — that is the only window iOS Safari accepts for unlock.
///
/// Creates (or reuses) a Web Audio AudioContext and calls resume() on it.
/// After this, the browser marks the page as having "sticky user activation",
/// so soundpool_web's AudioContext (created asynchronously inside init()) will
/// also start in 'running' state on iOS Safari 14.5+.
void unlockWebAudio() {
  try {
    _ctx ??= web.AudioContext();
    _ctx!.resume(); // JSPromise — fire and forget; idempotent if already running
  } catch (_) {
    // AudioContext unsupported on very old browsers — silently ignore
  }
}

/// Registers a one-time visibilitychange listener.
/// When the page returns from background (screen-lock / tab-switch):
///   • Resumes our AudioContext so the Web Audio engine can start scheduling.
///   • Calls [onVisible] so the caller can restart any interrupted audio.
void setupVisibilityListener(void Function() onVisible) {
  if (_listenerSetup) return;
  _listenerSetup = true;
  web.document.addEventListener(
    'visibilitychange',
    ((JSAny? _) {
      if (web.document.visibilityState == 'visible') {
        _ctx?.resume();
        onVisible();
      }
    }).toJS,
  );
}
