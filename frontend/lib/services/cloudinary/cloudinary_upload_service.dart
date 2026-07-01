import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.publicId,
    required this.secureUrl,
    required this.thumbnailUrl,
  });

  final String publicId;
  final String secureUrl;
  final String thumbnailUrl;

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    final publicId = json['public_id'] as String? ?? '';
    final secureUrl = json['secure_url'] as String? ?? '';
    return CloudinaryUploadResult(
      publicId: publicId,
      secureUrl: secureUrl,
      thumbnailUrl: secureUrl.isEmpty
          ? ''
          : secureUrl.replaceFirst('/video/upload/', '/video/upload/so_0/'),
    );
  }
}

class CloudinaryUploadService {
  Future<CloudinaryUploadResult> uploadVideo(XFile file) async {
    if (!AppConfig.hasCloudinaryConfig) {
      throw StateError(
        'Cloudinary is not configured. Missing: '
        '${AppConfig.missingCloudinaryFields.join(', ')}. Create an unsigned '
        'Cloudinary upload preset and pass these values with --dart-define.',
      );
    }

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/${AppConfig.cloudinaryCloudName}/video/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = AppConfig.cloudinaryUploadFolder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          await file.readAsBytes(),
          filename: file.name.isEmpty ? 'reflection.mp4' : file.name,
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body['error'] is Map
          ? (body['error'] as Map)['message']
          : 'Cloudinary upload failed';
      throw StateError(message.toString());
    }
    return CloudinaryUploadResult.fromJson(body);
  }
}
