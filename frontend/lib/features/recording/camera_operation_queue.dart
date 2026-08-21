import 'dart:async';

class CameraOperationQueue {
  Future<void> _tail = Future<void>.value();
  Future<void>? _activeInitialization;

  bool get isInitializing => _activeInitialization != null;

  Future<void> initialize(Future<void> Function() operation) {
    final active = _activeInitialization;
    if (active != null) return active;

    late final Future<void> tracked;
    tracked = enqueue(operation).whenComplete(() {
      if (identical(_activeInitialization, tracked)) {
        _activeInitialization = null;
      }
    });
    _activeInitialization = tracked;
    return tracked;
  }

  Future<void> enqueue(Future<void> Function() operation) {
    final next = _tail.then<void>(
      (_) => operation(),
      onError: (_) => operation(),
    );
    _tail = next;
    return next;
  }

  void cancelInitialization() {
    _activeInitialization = null;
  }
}
