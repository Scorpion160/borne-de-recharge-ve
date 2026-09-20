param(
  [string]$Target = "frontend/vescope"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter n'est pas disponible dans PATH."
}

Write-Host "[VE-SCOPE] Flutter:" -ForegroundColor Cyan
flutter --version

if (Test-Path $Target) {
  if (Test-Path (Join-Path $Target "pubspec.yaml")) {
    Write-Host "[VE-SCOPE] Le projet Flutter existe déjà: $Target" -ForegroundColor Yellow
  } else {
    throw "Le dossier $Target existe mais n'est pas un projet Flutter."
  }
} else {
  flutter create `
    --org sn.vescope `
    --project-name vescope `
    --platforms android,ios,web,windows `
    $Target
}

Push-Location $Target
try {
  flutter pub add http
  flutter pub add web_socket_channel
  flutter pub add flutter_blue_plus
  flutter pub add shared_preferences
  flutter pub add fl_chart
  flutter pub add dio
  flutter pub add path_provider
  flutter pub add share_plus
  flutter pub add url_launcher

  flutter analyze
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "[VE-SCOPE] Bootstrap Flutter terminé." -ForegroundColor Green
Write-Host "Ajoutez ensuite frontend/vescope au commit de la branche agent/vescope-field-v1."
