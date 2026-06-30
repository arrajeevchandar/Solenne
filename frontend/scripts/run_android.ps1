param(
  [string]$DeviceId = "",
  [string]$CloudinaryCloudName = $env:CLOUDINARY_CLOUD_NAME,
  [string]$CloudinaryUploadPreset = $env:CLOUDINARY_UPLOAD_PRESET
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($CloudinaryCloudName)) {
  throw "Set CLOUDINARY_CLOUD_NAME or pass -CloudinaryCloudName."
}

if ([string]::IsNullOrWhiteSpace($CloudinaryUploadPreset)) {
  throw "Set CLOUDINARY_UPLOAD_PRESET or pass -CloudinaryUploadPreset."
}

$flutterArgs = @(
  "run",
  "--dart-define=CLOUDINARY_CLOUD_NAME=$CloudinaryCloudName",
  "--dart-define=CLOUDINARY_UPLOAD_PRESET=$CloudinaryUploadPreset"
)

if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
  $flutterArgs = @("run", "-d", $DeviceId) + $flutterArgs[1..($flutterArgs.Length - 1)]
}

& flutter @flutterArgs
