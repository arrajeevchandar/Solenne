param(
  [string]$CloudinaryCloudName = $env:CLOUDINARY_CLOUD_NAME,
  [string]$CloudinaryUploadPreset = $env:CLOUDINARY_UPLOAD_PRESET
)

$ErrorActionPreference = "Stop"

$flutterArgs = @("run", "-d", "chrome")

if (-not [string]::IsNullOrWhiteSpace($CloudinaryCloudName)) {
  $flutterArgs += "--dart-define=CLOUDINARY_CLOUD_NAME=$CloudinaryCloudName"
}

if (-not [string]::IsNullOrWhiteSpace($CloudinaryUploadPreset)) {
  $flutterArgs += "--dart-define=CLOUDINARY_UPLOAD_PRESET=$CloudinaryUploadPreset"
}

Write-Host "Running the real Solenne app in Chrome. Cloudinary defaults are built in; passed values override them."
Write-Host "Keep this session open and press 'r' for hot reload."

& flutter @flutterArgs
