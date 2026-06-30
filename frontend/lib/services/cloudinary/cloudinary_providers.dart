import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloudinary_upload_service.dart';

final cloudinaryUploadServiceProvider = Provider<CloudinaryUploadService>((ref) {
  return CloudinaryUploadService();
});
