import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/services/cloudinary/cloudinary_upload_service.dart';

void main() {
  test('parses Cloudinary video upload response', () {
    final result = CloudinaryUploadResult.fromJson({
      'public_id': 'solenne/journals/abc123',
      'secure_url':
          'https://res.cloudinary.com/demo/video/upload/v123/solenne/journals/abc123.mp4',
    });

    expect(result.publicId, 'solenne/journals/abc123');
    expect(result.secureUrl, contains('/video/upload/'));
    expect(result.thumbnailUrl, contains('/video/upload/so_0/'));
  });
}
