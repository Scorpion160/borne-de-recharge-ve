$ErrorActionPreference = "Stop"

$Certificates = @(
  @{ Name = "ISRG Root X1"; Url = "https://letsencrypt.org/certs/isrgrootx1.pem" },
  @{ Name = "ISRG Root X2"; Url = "https://letsencrypt.org/certs/isrg-root-x2.pem" },
  @{ Name = "ISRG Root YE"; Url = "https://letsencrypt.org/certs/gen-y/root-ye.pem" },
  @{ Name = "ISRG Root YR"; Url = "https://letsencrypt.org/certs/gen-y/root-yr.pem" }
)

$Target = Join-Path $PSScriptRoot "..\firmware\vescope-core-esp32\include\mqtt_ca.h"
$PemBlocks = New-Object System.Collections.Generic.List[string]

foreach ($cert in $Certificates) {
  $safeName = ($cert.Name -replace '[^A-Za-z0-9_-]', '-')
  $temp = Join-Path $env:TEMP ("vescope-" + $safeName + ".pem")
  Write-Host ("[VE-SCOPE] Telechargement " + $cert.Name + "...") -ForegroundColor Cyan

  try {
    Invoke-WebRequest -UseBasicParsing -Uri $cert.Url -OutFile $temp
    $pem = (Get-Content -Path $temp -Raw -Encoding ASCII).Trim()
  }
  finally {
    Remove-Item -Path $temp -Force -ErrorAction SilentlyContinue
  }

  if (-not $pem.Contains("BEGIN CERTIFICATE") -or -not $pem.Contains("END CERTIFICATE")) {
    throw ("Le contenu telecharge pour " + $cert.Name + " n'est pas un certificat PEM valide.")
  }

  $PemBlocks.Add($pem)
}

$bundle = $PemBlocks -join "`r`n"
$header = @"
#pragma once

// Let's Encrypt trust bundle for VE-SCOPE cloud TLS.
// Sources: letsencrypt.org/certificates/ (X1, X2, Root YE, Root YR).
static const char VESCOPE_MQTT_ROOT_CA[] PROGMEM = R"VESCOPE_CA(
$bundle
)VESCOPE_CA";
"@

Set-Content -Path $Target -Value $header -Encoding ASCII
Write-Host "[VE-SCOPE] Bundle CA MQTT/HTTPS cree: $Target" -ForegroundColor Green
Write-Host ("[VE-SCOPE] Certificats inclus: " + $Certificates.Count) -ForegroundColor Green
