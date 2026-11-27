#Requires -Version 5.1
<#
.SYNOPSIS
  Local F-Droid listing checks before tagging and filing the RFP.
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

Write-Host '==> Fastlane / FOSS metadata tests'
& flutter test test/fastlane_metadata_test.dart test/utils/font_licenses_test.dart
if ($LASTEXITCODE -ne 0) {
    throw 'Metadata tests failed'
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
    Write-Host 'Do not tag v1.4.1 again (no Fastlane on that release). Commit this tree, then ./scripts/release.ps1 for v1.4.2.' -ForegroundColor Yellow
} elseif ($tags -match "^v$version$") {
    Write-Host "Tag v$version already exists. Bump with ./scripts/release.ps1 before the RFP." -ForegroundColor Yellow
} else {
    Write-Host "Next listing tag should be v$version after this tree is committed and pushed."
}

Write-Host ''
Write-Host 'GitHub still has no Fastlane until this tree is pushed.'
Write-Host 'After the tag exists: paste docs/fdroid-rfp-issue.md into https://gitlab.com/fdroid/rfp/-/issues'
Write-Host 'Preflight OK.' -ForegroundColor Green
