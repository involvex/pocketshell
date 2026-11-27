#Requires -Version 5.1
<#
.SYNOPSIS
  Create a local Android upload keystore and optional GitHub Actions secrets.

.DESCRIPTION
  Writes android/app/upload-keystore.jks + android/keystore.properties (gitignored).
  Passwords are never printed. Use -UploadSecrets to pipe values into `gh secret set`
  (stdin; not argv).

.EXAMPLE
  ./scripts/setup-android-keystore.ps1
.EXAMPLE
  ./scripts/setup-android-keystore.ps1 -UploadSecrets
#>
param(
    [string]$Alias = 'upload',
    [string]$StoreFileName = 'upload-keystore.jks',
    [switch]$UploadSecrets,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$AndroidDir = Join-Path $RepoRoot 'android'
$AppDir = Join-Path $AndroidDir 'app'
$JksPath = Join-Path $AppDir $StoreFileName
$PropsPath = Join-Path $AndroidDir 'keystore.properties'

function Read-Secret([string]$Prompt) {
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

if ((Test-Path $JksPath) -and -not $Force) {
    throw "Keystore already exists at $JksPath (pass -Force to overwrite)."
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    throw 'keytool not found. Install a JDK 17+ and ensure keytool is on PATH.'
}

Write-Host 'Passwords are hidden and never logged.'
$storePassword = Read-Secret 'Keystore password'
$keyPassword = Read-Secret 'Key password (Enter = same as keystore)'
if ([string]::IsNullOrEmpty($keyPassword)) {
    $keyPassword = $storePassword
}
$cn = Read-Host -Prompt 'Certificate CN (e.g. PocketShell Upload)'
if ([string]::IsNullOrWhiteSpace($cn)) {
    $cn = 'PocketShell Upload'
}

$dname = "CN=$cn, OU=Mobile, O=Involvex, L=Unknown, ST=Unknown, C=US"
Write-Host "==> Generating $JksPath (RSA 2048, 10000 days, alias=$Alias)"
& keytool -genkeypair `
    -v `
    -storetype PKCS12 `
    -keystore $JksPath `
    -alias $Alias `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -storepass $storePassword `
    -keypass $keyPassword `
    -dname $dname
if ($LASTEXITCODE -ne 0) {
    throw 'keytool -genkeypair failed'
}

@"
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$Alias
storeFile=$StoreFileName
"@ | Set-Content -Path $PropsPath -Encoding ascii -NoNewline
Write-Host "Wrote $PropsPath (gitignored)."

if ($UploadSecrets) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw 'gh not found; install GitHub CLI or upload secrets manually (docs/android-signing.md).'
    }
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($JksPath))
    Write-Host '==> Uploading ANDROID_KEYSTORE_* via gh secret set (stdin)'
    $b64 | & gh secret set ANDROID_KEYSTORE_BASE64 --repo involvex/pocketshell
    if ($LASTEXITCODE -ne 0) { throw 'Failed to set ANDROID_KEYSTORE_BASE64' }
    $storePassword | & gh secret set ANDROID_KEYSTORE_PASSWORD --repo involvex/pocketshell
    if ($LASTEXITCODE -ne 0) { throw 'Failed to set ANDROID_KEYSTORE_PASSWORD' }
    $Alias | & gh secret set ANDROID_KEY_ALIAS --repo involvex/pocketshell
    if ($LASTEXITCODE -ne 0) { throw 'Failed to set ANDROID_KEY_ALIAS' }
    $keyPassword | & gh secret set ANDROID_KEY_PASSWORD --repo involvex/pocketshell
    if ($LASTEXITCODE -ne 0) { throw 'Failed to set ANDROID_KEY_PASSWORD' }
    Write-Host 'GitHub Actions secrets set (names only; values not shown).' -ForegroundColor Green
} else {
    Write-Host 'Skipped GitHub secrets. Re-run with -UploadSecrets or set them per docs/android-signing.md'
}

Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host '  1. flutter build apk --release   (or ./scripts/build-izzy-apk.ps1)'
Write-Host '  2. commit_push listing work, then tag a release so CI attaches *-izzy.apk'
Write-Host '  3. File Izzy request using docs/izzyondroid-request.md'
