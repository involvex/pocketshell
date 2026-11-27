#Requires -Version 5.1
<#
.SYNOPSIS
  Render Fastlane phone screenshots from Flutter widget tests (no adb).

  These are the real Material widgets at 1080x1920. Replace with device
  captures from capture-fdroid-screenshots.ps1 if you want a live SSH session.
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

$previous = $env:FDROID_SCREENSHOTS
$env:FDROID_SCREENSHOTS = '1'
try {
    & flutter test test/fdroid_screenshots_test.dart --name "write Fastlane"
    if ($LASTEXITCODE -ne 0) {
        throw "Screenshot render failed ($LASTEXITCODE)"
    }
} finally {
    if ($null -eq $previous) {
        Remove-Item Env:FDROID_SCREENSHOTS -ErrorAction SilentlyContinue
    } else {
        $env:FDROID_SCREENSHOTS = $previous
    }
}

$shotDir = Join-Path $RepoRoot 'fastlane/metadata/android/en-US/images/phoneScreenshots'
$pngs = @(Get-ChildItem -Path $shotDir -Filter '*.png' -ErrorAction SilentlyContinue)
Write-Host "Wrote $($pngs.Count) PNG(s) to $shotDir"
foreach ($png in $pngs) {
    Write-Host "  $($png.Name)  $($png.Length) bytes"
}
