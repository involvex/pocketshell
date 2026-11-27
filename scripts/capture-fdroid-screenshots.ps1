#Requires -Version 5.1
<#
.SYNOPSIS
  Capture F-Droid phone screenshots from an attached Android device.

  Run this yourself (it uses adb on your phone). Set up each screen, then press Enter.

.EXAMPLE
  ./scripts/capture-fdroid-screenshots.ps1
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$OutDir = Join-Path $RepoRoot 'fastlane/metadata/android/en-US/images/phoneScreenshots'

$shots = @(
    @{ File = '01-client.png'; Hint = 'Client tab with a connected terminal' }
    @{ File = '02-sftp.png'; Hint = 'SFTP browser on a remote folder' }
    @{ File = '03-agents.png'; Hint = 'Agents tab chat with a session open' }
    @{ File = '04-privacy.png'; Hint = 'Settings → About → Privacy' }
    @{ File = '05-host-key.png'; Hint = 'Unknown host-key trust dialog (connect to a new host)' }
    @{ File = '06-widgets.png'; Hint = 'Android home screen showing PocketShell widgets' }
)

function Get-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        throw 'adb is not on PATH. Install Android platform-tools, then re-run this script.'
    }
    return $cmd.Source
}

$adb = Get-Adb
$devices = & $adb devices
$serialLines = $devices | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' }
if (-not $serialLines) {
    throw 'No authorized Android device. Enable USB debugging, authorize this PC, then re-run.'
}

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

Write-Host "Saving PNGs to $OutDir"
Write-Host 'Max aspect 2:1 (height:width). Portrait phone screenshots are fine.'
Write-Host ''

$remote = '/sdcard/pocketshell-fdroid-shot.png'
foreach ($shot in $shots) {
    Write-Host "==> $($shot.File)" -ForegroundColor Cyan
    Write-Host "    $($shot.Hint)"
    Read-Host '    Arrange the screen on the phone, then press Enter'

    $dest = Join-Path $OutDir $shot.File
    & $adb shell screencap -p $remote
    if ($LASTEXITCODE -ne 0) {
        throw "screencap failed for $($shot.File)"
    }
    & $adb pull $remote $dest
    if ($LASTEXITCODE -ne 0) {
        throw "adb pull failed for $($shot.File)"
    }
    Write-Host "    Wrote $dest" -ForegroundColor Green
}

& $adb shell rm $remote 2>$null
Write-Host ''
Write-Host 'Done. Open docs/fdroid-rfp.md and paste the GitLab RFP after the next tagged release.'
