class CameraVisibilityObserver {
  CameraVisibilityObserver({required this.onVisibilityChanged});

  final void Function(bool isVisible) onVisibilityChanged;

  void start() {}

  void dispose() {}
}
