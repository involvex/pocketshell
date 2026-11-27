#Requires -Version 5.1
<#
.SYNOPSIS
  Bump semver + build in pubspec.yaml, update CHANGELOG, commit, tag, and push.

.EXAMPLE
  ./scripts/release.ps1

.EXAMPLE
  ./scripts/release.ps1 -DryRun

.EXAMPLE
  ./scripts/release.ps1 -Message "Fix connection timeout"
#>
param(
    [ValidateSet('patch', 'minor', 'major')]
    [string] $Bump = 'patch',

    [string] $Message = '',

    [switch] $DryRun,
    [switch] $NoPush,
    [switch] $SkipTests
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

function Write-Step([string] $Text) {
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Invoke-OrPrint {
    param(
        [string[]] $Command,
        [string] $Description
    )
    $joined = $Command -join ' '
    if ($DryRun) {
        Write-Host "[dry-run] $Description`: $joined" -ForegroundColor Yellow
        return
    }
    Write-Step $Description
    & $Command[0] @($Command[1..($Command.Length - 1)])
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $joined"
    }
}

function Get-PubspecVersion {
    $pubspecPath = Join-Path $RepoRoot 'pubspec.yaml'
    $content = Get-Content $pubspecPath -Raw
    if ($content -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
        throw 'Could not parse version from pubspec.yaml (expected MAJOR.MINOR.PATCH+BUILD)'
    }
    return [pscustomobject]@{
        Major       = [int] $Matches[1]
        Minor       = [int] $Matches[2]
        Patch       = [int] $Matches[3]
        Build       = [int] $Matches[4]
        Version     = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
        Full        = "$($Matches[1]).$($Matches[2]).$($Matches[3])+$($Matches[4])"
        PubspecPath = $pubspecPath
    }
}

function Set-PubspecVersion {
    param(
        [string] $NewFull
    )
    $pubspecPath = Join-Path $RepoRoot 'pubspec.yaml'
    $content = Get-Content $pubspecPath -Raw
    $updated = [regex]::Replace(
        $content,
        '(?m)^version:\s*.+$',
        "version: $NewFull"
    )
    if ($DryRun) {
        Write-Host "[dry-run] pubspec.yaml version -> $NewFull" -ForegroundColor Yellow
        return
    }
    Set-Content -Path $pubspecPath -Value $updated -NoNewline
}

function Add-ChangelogEntry {
    param(
        [string] $Version,
        [string] $Date,
        [string] $Bullet
    )
    $changelogPath = Join-Path $RepoRoot 'CHANGELOG.md'
    if (-not (Test-Path $changelogPath)) {
        throw 'CHANGELOG.md not found'
    }
    $entry = @"
## [$Version] - $Date

### Changed

- $Bullet

"@
    if ($DryRun) {
        Write-Host "[dry-run] Prepend to CHANGELOG.md:`n$entry" -ForegroundColor Yellow
        return
    }
    $existing = Get-Content $changelogPath -Raw
    if ($existing -notmatch '(?s)## \[Unreleased\]') {
        throw 'CHANGELOG.md must contain an ## [Unreleased] section'
    }
    $updated = $existing -replace '(## \[Unreleased\]\s*)', "`$1`n$entry"
    Set-Content -Path $changelogPath -Value $updated -NoNewline
}

function Test-CleanWorkingTree {
    $status = git status --porcelain
    if ([string]::IsNullOrWhiteSpace($status)) {
        return
    }
    if ($DryRun) {
        Write-Host '[dry-run] Working tree is not clean (would abort in real run):' -ForegroundColor Yellow
        Write-Host $status
        return
    }
    throw "Working tree is not clean. Commit or stash changes before releasing.`n$status"
}

function Test-FastlaneTracked {
    $tracked = git ls-files -- 'fastlane/metadata/android/en-US/title.txt'
    if (-not [string]::IsNullOrWhiteSpace($tracked)) {
        return
    }
    $msg = 'fastlane/metadata/android/en-US/title.txt is not tracked. Commit the store-readiness tree before tagging (F-Droid issuebot).'
    if ($DryRun) {
        Write-Host "[dry-run] $msg" -ForegroundColor Yellow
        return
    }
    throw $msg
}

function Test-TagAvailable {
    param([string] $Tag)
    $local = git tag -l $Tag
    if ($local) {
        throw "Tag already exists locally: $Tag"
    }
    if ($DryRun) {
        Write-Host "[dry-run] Would check remote for tag $Tag" -ForegroundColor Yellow
        return
    }
    git fetch --tags origin 2>$null
    $remote = git ls-remote --tags origin "refs/tags/$Tag"
    if ($remote) {
        throw "Tag already exists on remote: $Tag"
    }
}

# --- main ---
Write-Step "Release bump: $Bump"

Test-CleanWorkingTree
Test-FastlaneTracked

$current = Get-PubspecVersion
$major = $current.Major
$minor = $current.Minor
$patch = $current.Patch
$build = $current.Build + 1

switch ($Bump) {
    'major' {
        $major++
        $minor = 0
        $patch = 0
    }
    'minor' {
        $minor++
        $patch = 0
    }
    'patch' {
        $patch++
    }
}

$newVersion = "$major.$minor.$patch"
$newFull = "$newVersion+$build"
$tag = "v$newVersion"
$date = Get-Date -Format 'yyyy-MM-dd'

if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = "v$newVersion"
}

Write-Host "Current: $($current.Full)"
Write-Host "New:     $newFull"
Write-Host "Tag:     $tag"

Test-TagAvailable -Tag $tag

function Add-FastlaneChangelog {
    param(
        [int] $VersionCode,
        [string] $Bullet
    )
    $dir = Join-Path $RepoRoot 'fastlane/metadata/android/en-US/changelogs'
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $path = Join-Path $dir "$VersionCode.txt"
    $text = $Bullet
    if ($text.Length -gt 500) {
        $text = $text.Substring(0, 500)
    }
    if ($DryRun) {
        Write-Host "[dry-run] Fastlane changelog $path -> $text" -ForegroundColor Yellow
        return
    }
    Set-Content -Path $path -Value $text -NoNewline
}

Set-PubspecVersion -NewFull $newFull
Add-ChangelogEntry -Version $newVersion -Date $date -Bullet $Message
# Universal GitHub APK uses pubspec build number; F-Droid ABI splits use
# versionCode * 10 + {1,2,3} (see android/app/build.gradle.kts).
Add-FastlaneChangelog -VersionCode $build -Bullet $Message
Add-FastlaneChangelog -VersionCode (10 * $build + 1) -Bullet $Message
Add-FastlaneChangelog -VersionCode (10 * $build + 2) -Bullet $Message
Add-FastlaneChangelog -VersionCode (10 * $build + 3) -Bullet $Message

Invoke-OrPrint -Command @('flutter', 'pub', 'get') -Description 'flutter pub get'
Invoke-OrPrint -Command @('flutter', 'analyze') -Description 'flutter analyze'

if (-not $SkipTests) {
    Invoke-OrPrint -Command @('flutter', 'test') -Description 'flutter test'
} elseif ($DryRun) {
    Write-Host '[dry-run] Skipping flutter test (-SkipTests)' -ForegroundColor Yellow
}

$commitMsg = "chore(release): v$newVersion"
Invoke-OrPrint -Command @('git', 'add', 'pubspec.yaml', 'CHANGELOG.md', 'fastlane/metadata/android/en-US/changelogs') -Description 'git add'
Invoke-OrPrint -Command @('git', 'commit', '-m', $commitMsg) -Description 'git commit'
Invoke-OrPrint -Command @('git', 'tag', '-a', $tag, '-m', $tag) -Description 'git tag'

if ($NoPush) {
    if ($DryRun) {
        Write-Host '[dry-run] Skipping push (-NoPush)' -ForegroundColor Yellow
    } else {
        Write-Host 'Skipping push (-NoPush). Run manually:' -ForegroundColor Green
        Write-Host "  git push origin HEAD"
        Write-Host "  git push origin $tag"
    }
} else {
    Invoke-OrPrint -Command @('git', 'push', 'origin', 'HEAD') -Description 'git push branch'
    Invoke-OrPrint -Command @('git', 'push', 'origin', $tag) -Description 'git push tag'
}

Write-Host "Release $tag complete." -ForegroundColor Green

$shotDir = Join-Path $RepoRoot 'fastlane/metadata/android/en-US/images/phoneScreenshots'
$pngs = @(Get-ChildItem -Path $shotDir -Filter '*.png' -ErrorAction SilentlyContinue)
if ($pngs.Count -lt 4) {
    Write-Host "Fastlane phone screenshots: $($pngs.Count) PNG(s). Capture 4-6 with ./scripts/capture-fdroid-screenshots.ps1 before filing the F-Droid RFP." -ForegroundColor Yellow
}
