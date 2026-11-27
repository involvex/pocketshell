#Requires -Version 5.1
<#
.SYNOPSIS
  Write fastlane/metadata/android/en-US/images/featureGraphic.png (1024x500).
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$iconPath = Join-Path $RepoRoot 'fastlane/metadata/android/en-US/images/icon.png'
$outPath = Join-Path $RepoRoot 'fastlane/metadata/android/en-US/images/featureGraphic.png'

if (-not (Test-Path $iconPath)) {
    throw "Missing launcher icon at $iconPath"
}

Add-Type -AssemblyName System.Drawing

$width = 1024
$height = 500
$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$g.Clear([System.Drawing.Color]::FromArgb(26, 39, 68))

$icon = [System.Drawing.Image]::FromFile($iconPath)
$iconSize = 320
$iconX = 72
$iconY = [int](($height - $iconSize) / 2)
$g.DrawImage($icon, $iconX, $iconY, $iconSize, $iconSize)

$fontFamily = New-Object System.Drawing.FontFamily 'Segoe UI'
$titleFont = New-Object System.Drawing.Font $fontFamily, 52, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$subFont = New-Object System.Drawing.Font $fontFamily, 22, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(232, 237, 243))
$subBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(156, 178, 201))
$accentBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(76, 175, 80))

$textX = 430
$g.DrawString('PocketShell', $titleFont, $titleBrush, $textX, 145)
$g.DrawString('SSH, SFTP, and OpenCode agents', $subFont, $subBrush, $textX, 240)
$g.FillRectangle($accentBrush, $textX, 300, 160, 8)

$outDir = Split-Path $outPath
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bmp.Dispose()
$icon.Dispose()
$titleFont.Dispose()
$subFont.Dispose()
$fontFamily.Dispose()
$titleBrush.Dispose()
$subBrush.Dispose()
$accentBrush.Dispose()

Write-Host "Wrote $outPath"
