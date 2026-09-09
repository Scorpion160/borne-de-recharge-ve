$ErrorActionPreference = "Stop"

$Url = "https://letsencrypt.org/certs/isrgrootx1.pem"
$Target = Join-Path $PSScriptRoot "..\firmware\vescope-core-esp32\include\mqtt_ca.h"

Write-Host "[VE-SCOPE] Téléchargement ISRG Root X1..." -ForegroundColor Cyan
$pem = (Invoke-WebRequest -UseBasicParsing $Url).Content.Trim()

if (-not $pem.Contains("BEGIN CERTIFICATE") -or -not $pem.Contains("END CERTIFICATE")) {
  throw "Le contenu téléchargé n'est pas un certificat PEM valide."
}

$header = @"
#pragma once

// ISRG Root X1 - récupéré depuis letsencrypt.org/certs/isrgrootx1.pem
static const char VESCOPE_MQTT_ROOT_CA[] PROGMEM = R"VESCOPE_CA(
$pem
)VESCOPE_CA";
"@

Set-Content -Path $Target -Value $header -Encoding ascii
Write-Host "[VE-SCOPE] CA MQTT créée: $Target" -ForegroundColor Green
