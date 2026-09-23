$ErrorActionPreference = 'Stop'
$Project = Join-Path $PSScriptRoot '..\frontend\vescope_flutter'
Push-Location $Project
try {
    if (-not (Test-Path 'android\app\src\main\AndroidManifest.xml')) {
        throw 'Le projet Android manque. Executer flutter create --platforms=android --org com.vescope --project-name vescope_supervisor . puis relancer ce script.'
    }
    $ManifestPath = Join-Path (Get-Location) 'android\app\src\main\AndroidManifest.xml'
    [xml]$Manifest = Get-Content -Raw $ManifestPath
    $AndroidNs = 'http://schemas.android.com/apk/res/android'
    $HasInternet = @($Manifest.manifest.'uses-permission') | Where-Object {
        $_ -and $_.GetAttribute('name', $AndroidNs) -eq 'android.permission.INTERNET'
    }
    if (-not $HasInternet) {
        $Permission = $Manifest.CreateElement('uses-permission')
        $Permission.SetAttribute('name', $AndroidNs, 'android.permission.INTERNET')
        [void]$Manifest.manifest.AppendChild($Permission)
    }
    $Manifest.manifest.application.SetAttribute('label', $AndroidNs, 'VE-SCOPE')
    $Manifest.Save($ManifestPath)

    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get a echoue' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze a echoue' }
    flutter test test/mobile_session_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Tests de connexion en echec' }
    flutter build apk --release --dart-define=VESCOPE_API_BASE=https://vescope.kerunjombor.net --dart-define=VESCOPE_WS_URL=wss://vescope.kerunjombor.net/api/v1/ws/devices/borne-01
    if ($LASTEXITCODE -ne 0) { throw 'Compilation APK en echec' }
    Get-Item 'build\app\outputs\flutter-apk\app-release.apk' | Select-Object FullName, Length, LastWriteTime
} finally {
    Pop-Location
}
