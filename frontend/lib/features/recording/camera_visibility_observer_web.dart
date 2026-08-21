import 'dart:js_interop';

import 'package:web/web.dart' as web;

class CameraVisibilityObserver {
  CameraVisibilityObserver({required this.onVisibilityChanged});

  final void Function(bool isVisible) onVisibilityChanged;
  JSFunction? _listener;

  void start() {
    if (_listener != null) return;
    _listener = _handleVisibilityChange.toJS;
    web.document.addEventListener('visibilitychange', _listener);
  }

  void dispose() {
    final listener = _listener;
    if (listener == null) return;
    web.document.removeEventListener('visibilitychange', listener);
    _listener = null;
  }

  void _handleVisibilityChange(web.Event _) {
    onVisibilityChanged(web.document.visibilityState == 'visible');
  }
}
