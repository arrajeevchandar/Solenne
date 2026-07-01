class AppConfig {
  static const cloudinaryDefaultCloudName = '';
  static const cloudinaryDefaultUploadPreset = '';
  static const cloudinaryUploadFolder = 'solenne/journals';

  static const cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: cloudinaryDefaultCloudName,
  );
  static const cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: cloudinaryDefaultUploadPreset,
  );

  static bool get hasCloudinaryConfig =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  static List<String> get missingCloudinaryFields {
    return [
      if (cloudinaryCloudName.isEmpty) 'CLOUDINARY_CLOUD_NAME',
      if (cloudinaryUploadPreset.isEmpty) 'CLOUDINARY_UPLOAD_PRESET',
    ];
  }
}
