#Requires -Version 5.1
<#
.SYNOPSIS
  Local F-Droid listing checks before tagging and filing the RFP.
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

Write-Host '==> Fastlane / FOSS metadata tests'
& flutter test `
    test/fastlane_metadata_test.dart `
    test/utils/font_licenses_test.dart `
    test/services/ai_gateway_service_test.dart `
    test/constants/cloud_ai_test.dart
if ($LASTEXITCODE -ne 0) {
    throw 'Metadata tests failed'
}

$cloudAi = Get-Content -Raw (Join-Path $RepoRoot 'lib/constants/cloud_ai.dart')
if ($cloudAi -notmatch 'CLOUD_AI') {
    throw 'lib/constants/cloud_ai.dart must define CLOUD_AI dart-define for Izzy builds'
}
$releaseYml = Get-Content -Raw (Join-Path $RepoRoot '.github/workflows/release.yml')
if ($releaseYml -notmatch 'CLOUD_AI=false') {
    throw 'release.yml must build an Izzy APK with --dart-define=CLOUD_AI=false'
}
if (-not (Test-Path (Join-Path $RepoRoot 'scripts/build-izzy-apk.ps1'))) {
    throw 'scripts/build-izzy-apk.ps1 is required for local Izzy APK + dex scan'
}
$izzyLocal = Join-Path $RepoRoot 'build/app/outputs/flutter-apk/PocketShell-izzy-local.apk'
if (Test-Path $izzyLocal) {
    Write-Host '==> Re-scanning existing PocketShell-izzy-local.apk'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $izzyLocal))
    try {
        foreach ($entry in ($zip.Entries | Where-Object { $_.FullName -like '*.dex' })) {
            $stream = $entry.Open()
            try {
                $ms = New-Object System.IO.MemoryStream
                $stream.CopyTo($ms)
                $ascii = [Text.Encoding]::ASCII.GetString($ms.ToArray())
                if ($ascii.Contains('opencode.ai') -or $ascii.Contains('api.kilo.ai')) {
                    throw 'PocketShell-izzy-local.apk still contains LLM gateway strings'
                }
            } finally {
                $stream.Dispose()
            }
        }
        Write-Host '  OK: Izzy local APK dex clean'
    } finally {
        $zip.Dispose()
    }
}

$recipe = Get-Content -Raw (Join-Path $RepoRoot 'docs/fdroid.yml')
if ($recipe -notmatch 'enforce-lockfile') {
    throw 'docs/fdroid.yml must use flutter pub get --enforce-lockfile'
}
if ($recipe -notmatch '-Xmx2G') {
    throw 'docs/fdroid.yml must lower Gradle heap for the F-Droid buildserver'
}
if ($recipe -notmatch 'org.gradle.daemon=false') {
    throw 'docs/fdroid.yml must disable the Gradle daemon on the buildserver'
}
if ($recipe -notmatch 'split-per-abi') {
    throw 'docs/fdroid.yml must build per-ABI APKs'
}
if ($recipe -notmatch 'ndk: 28.2.13676358') {
    throw 'docs/fdroid.yml must pin Flutter 3.47.9 NDK 28.2.13676358'
}
if ($recipe -notmatch 'foojay-resolver') {
    throw 'docs/fdroid.yml must strip foojay-resolver (F-Droid usual-suspect scan)'
}
if ($recipe -notmatch 'isMinifyEnabled = true') {
    throw 'docs/fdroid.yml must enable R8 minify (strips Flutter Play Core stubs)'
}
if ($recipe -notmatch 'com\.google\.android\.play') {
    throw 'docs/fdroid.yml must exclude com.google.android.play'
}
$appGradle = Get-Content -Raw (Join-Path $RepoRoot 'android/app/build.gradle.kts')
if ($appGradle -notmatch 'isMinifyEnabled = true') {
    throw 'android/app/build.gradle.kts must enable R8 minify for F-Droid'
}
if ($appGradle -notmatch 'com\.google\.android\.play') {
    throw 'android/app/build.gradle.kts must exclude com.google.android.play'
}
if (-not (Test-Path (Join-Path $RepoRoot 'android/app/proguard-rules.pro'))) {
    throw 'android/app/proguard-rules.pro is required for Play Core -dontwarn'
}
$wrapperProps = Get-Content -Raw (Join-Path $RepoRoot 'android/gradle/wrapper/gradle-wrapper.properties')
if ($wrapperProps -notmatch 'distributionSha256Sum=') {
    throw 'gradle-wrapper.properties must set distributionSha256Sum (issuebot insecure-gradlew)'
}
if ($recipe -notmatch 'distributionSha256Sum=') {
    throw 'docs/fdroid.yml must set distributionSha256Sum for the listing tag wrapper'
}

$apkCandidates = @(
    'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    'build/app/outputs/flutter-apk/app-release.apk'
)
foreach ($rel in $apkCandidates) {
    $apkPath = Join-Path $RepoRoot $rel
    if (-not (Test-Path $apkPath)) {
        continue
    }
    Write-Host "==> Scanning $rel for Play Core / GMS strings"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $apkPath))
    try {
        $dexEntries = $zip.Entries | Where-Object { $_.FullName -like '*.dex' }
        foreach ($entry in $dexEntries) {
            $stream = $entry.Open()
            try {
                $ms = New-Object System.IO.MemoryStream
                $stream.CopyTo($ms)
                $ascii = [Text.Encoding]::ASCII.GetString($ms.ToArray())
                if ($ascii -match 'com[/.]google[/.]android[/.]play' -or
                    $ascii -match 'com[/.]google[/.]android[/.]gms' -or
                    $ascii -match 'firebase') {
                    throw "$rel still contains proprietary Google Play/GMS/Firebase strings in $($entry.FullName)"
                }
            } finally {
                $stream.Dispose()
            }
        }
        Write-Host "  OK: no Play Core / GMS / Firebase strings in dex ($($dexEntries.Count) dex file(s))"
    } finally {
        $zip.Dispose()
    }
    break
}

Get-ChildItem -Path (Join-Path $RepoRoot '.github/scripts') -Filter '*.sh' |
    ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        if ($bytes -contains 13) {
            throw "$($_.Name) has CR bytes; GitHub Actions bash needs LF"
        }
    }

$pubspec = Get-Content -Raw (Join-Path $RepoRoot 'pubspec.yaml')
if ($pubspec -notmatch 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
    throw 'Could not parse pubspec version'
}
$version = $Matches[1]
$code = $Matches[2]
Write-Host "pubspec version $version+$code"

$required = @(
    'PRIVACY.md',
    'THIRD_PARTY.md',
    'assets/fonts/OFL.txt',
    'assets/fonts/LICENSE',
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/FiraCode-Regular.ttf',
    'assets/fonts/SpaceMono-Regular.ttf',
    'assets/fonts/SourceCodePro-Regular.ttf',
    'docs/fdroid.yml',
    'android/app/src/main/res/xml/network_security_config.xml',
    'android/app/src/main/res/xml/backup_rules.xml',
    'android/app/src/main/res/xml/data_extraction_rules.xml',
    'fastlane/metadata/android/en-US/title.txt',
    'fastlane/metadata/android/en-US/full_description.txt',
    'fastlane/metadata/android/en-US/images/icon.png',
    'fastlane/metadata/android/en-US/images/featureGraphic.png',
    'fastlane/metadata/android/en-US/images/phoneScreenshots/01-client.png',
    'fastlane/metadata/android/en-US/images/phoneScreenshots/02-connect.png',
    'fastlane/metadata/android/en-US/images/phoneScreenshots/03-agents.png',
    'fastlane/metadata/android/en-US/images/phoneScreenshots/04-settings.png',
    'fastlane/metadata/android/en-US/images/phoneScreenshots/05-privacy.png',
    'fastlane/metadata/android/en-US/images/phoneScreenshots/06-host-key.png'
)
$untracked = @()
foreach ($rel in $required) {
    $tracked = git ls-files -- $rel
    if ([string]::IsNullOrWhiteSpace($tracked)) {
        $untracked += $rel
    }
}
if ($untracked.Count -gt 0) {
    Write-Host 'Untracked listing files (git add before commit / release.ps1):' -ForegroundColor Yellow
    $untracked | ForEach-Object { Write-Host "  $_" }
    throw 'Listing files are not in git yet; F-Droid issuebot would not see them.'
}

$dirty = git status --porcelain
if ($dirty) {
    Write-Host 'Working tree is dirty. Commit listing files before ./scripts/release.ps1' -ForegroundColor Yellow
}

$tags = git tag --list 'v*'
if ($version -eq '1.4.1') {
    Write-Host 'Do not tag v1.4.1 again (no Fastlane on that release). Use v1.4.2 or newer.' -ForegroundColor Yellow
} elseif ($tags -match "^v$version$") {
    Write-Host "Tag v$version is the listing target. Paste docs/fdroid-rfp-issue.md into https://gitlab.com/fdroid/rfp/-/issues"
} else {
    Write-Host "Next listing tag should be v$version after this tree is committed and pushed."
}

Write-Host ''
Write-Host 'Preflight OK.' -ForegroundColor Green
