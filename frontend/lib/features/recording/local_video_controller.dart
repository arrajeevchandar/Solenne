import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';

import 'local_video_controller_io.dart'
    if (dart.library.html) 'local_video_controller_web.dart';

VideoPlayerController createLocalVideoController(XFile file) {
  return createPlatformVideoController(file);
}
