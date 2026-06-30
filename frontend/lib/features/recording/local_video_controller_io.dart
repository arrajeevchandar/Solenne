import 'dart:io';

import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';

VideoPlayerController createPlatformVideoController(XFile file) {
  return VideoPlayerController.file(File(file.path));
}
