param(
  [ValidateSet('development', 'preview', 'production')]
  [string]$Profile = 'preview',
  [switch]$SkipFingerprint = $true
)

$ErrorActionPreference = 'Stop'

# Evita que un proxy local roto (127.0.0.1:9) rompa la conexión con EAS.
$env:ALL_PROXY = ''
$env:HTTP_PROXY = ''
$env:HTTPS_PROXY = ''
$env:GIT_HTTP_PROXY = ''
$env:GIT_HTTPS_PROXY = ''

if ($SkipFingerprint) {
  # Workaround para entornos Windows donde la huella automática puede fallar con EPERM.
  $env:EAS_SKIP_AUTO_FINGERPRINT = '1'
} else {
  Remove-Item Env:EAS_SKIP_AUTO_FINGERPRINT -ErrorAction SilentlyContinue
}

Write-Host "Lanzando EAS build Android (profile=$Profile)..."
eas build -p android --profile $Profile
exit $LASTEXITCODE
