class AppConfig {
  static const cloudinaryDefaultCloudName = 'dqjd3lszl';
  static const cloudinaryDefaultUploadPreset = 'solenne';
  static const cloudinaryUploadFolder = 'solenne/journals';

  static const cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: cloudinaryDefaultCloudName,
  );
  static const cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: cloudinaryDefaultUploadPreset,
  );
  static const exportApiBaseUrl = String.fromEnvironment(
    'EXPORT_API_BASE_URL',
    defaultValue: '',
  );

  static bool get hasCloudinaryConfig =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  static bool get hasExportApi => exportApiBaseUrl.trim().isNotEmpty;

  static List<String> get missingCloudinaryFields {
    return [
      if (cloudinaryCloudName.isEmpty) 'CLOUDINARY_CLOUD_NAME',
      if (cloudinaryUploadPreset.isEmpty) 'CLOUDINARY_UPLOAD_PRESET',
    ];
  }
}
