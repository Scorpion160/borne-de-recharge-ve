$ErrorActionPreference = 'Stop'
$Project = Join-Path $PSScriptRoot '..\frontend\vescope_flutter'
Push-Location $Project
try {
    if (-not (Test-Path 'windows\CMakeLists.txt')) {
        Write-Host 'Creation du projet Flutter Windows...'
        flutter create --platforms=windows --org com.vescope --project-name vescope_supervisor .
        if ($LASTEXITCODE -ne 0) { throw 'Creation du projet Windows en echec' }
    }

    # flutter create may add its stock counter test, which references MyApp.
    $SampleTest = 'test\widget_test.dart'
    if (Test-Path $SampleTest) {
        $SampleContent = Get-Content -Raw $SampleTest
        if ($SampleContent.Contains('await tester.pumpWidget(const MyApp());') -and
            $SampleContent.Contains("testWidgets('Counter increments smoke test'")) {
            Remove-Item $SampleTest
        }
    }

    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get a echoue' }
    dart run flutter_launcher_icons -f flutter_launcher_icons_windows.yaml
    if ($LASTEXITCODE -ne 0) { throw 'Generation de l icone Windows en echec' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze a echoue' }
    flutter test test/mobile_session_test.dart test/saved_credentials_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Tests en echec' }

    flutter build windows --release --dart-define=VESCOPE_API_BASE=https://vescope.kerunjombor.net --dart-define=VESCOPE_WS_URL=wss://vescope.kerunjombor.net/api/v1/ws/devices/borne-01
    if ($LASTEXITCODE -ne 0) { throw 'Compilation Windows en echec' }

    $ReleaseCandidates = @(
        'build\windows\x64\runner\Release',
        'build\windows\runner\Release'
    )
    $ReleaseDir = $ReleaseCandidates | Where-Object {
        (Test-Path (Join-Path $_ 'vescope_supervisor.exe')) -and
        (Test-Path (Join-Path $_ 'data'))
    } | Select-Object -First 1
    if (-not $ReleaseDir) {
        throw 'Executable et dossier data introuvables sous build\windows.'
    }

    $Archive = Join-Path (Get-Location) 'build\VE-SCOPE-Windows.zip'
    Compress-Archive -Path (Join-Path $ReleaseDir '*') -DestinationPath $Archive -Force
    Get-Item (Join-Path $ReleaseDir 'vescope_supervisor.exe'), $Archive |
        Select-Object FullName, Length, LastWriteTime
    Get-FileHash $Archive -Algorithm SHA256 | Select-Object Hash, Path
} finally {
    Pop-Location
}
