$ErrorActionPreference = "Stop"

$Url = "https://letsencrypt.org/certs/isrgrootx1.pem"
$Target = Join-Path $PSScriptRoot "..\firmware\vescope-core-esp32\include\mqtt_ca.h"
$Temp = Join-Path $env:TEMP "vescope-isrgrootx1.pem"

Write-Host "[VE-SCOPE] Telechargement ISRG Root X1..." -ForegroundColor Cyan

try {
  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Temp
  $pem = (Get-Content -Path $Temp -Raw -Encoding ASCII).Trim()
}
finally {
  Remove-Item -Path $Temp -Force -ErrorAction SilentlyContinue
}

if (-not $pem.Contains("BEGIN CERTIFICATE") -or -not $pem.Contains("END CERTIFICATE")) {
  throw "Le contenu telecharge n'est pas un certificat PEM valide."
}

$header = @"
#pragma once

// ISRG Root X1 - fetched from letsencrypt.org/certs/isrgrootx1.pem
static const char VESCOPE_MQTT_ROOT_CA[] PROGMEM = R"VESCOPE_CA(
$pem
)VESCOPE_CA";
"@

Set-Content -Path $Target -Value $header -Encoding ASCII
Write-Host "[VE-SCOPE] CA MQTT creee: $Target" -ForegroundColor Green
