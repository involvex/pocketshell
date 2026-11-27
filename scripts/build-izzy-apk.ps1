#Requires -Version 5.1
<#
.SYNOPSIS
  Build a CLOUD_AI=false release APK and fail if LLM gateway strings remain in dex.
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

Write-Host '==> flutter build apk --release --dart-define=CLOUD_AI=false --dart-define=AGENTS=false'
& flutter build apk --release --dart-define=CLOUD_AI=false --dart-define=AGENTS=false
if ($LASTEXITCODE -ne 0) {
    throw 'Izzy APK build failed'
}

$apk = Join-Path $RepoRoot 'build/app/outputs/flutter-apk/app-release.apk'
if (-not (Test-Path $apk)) {
    throw "Missing $apk"
}

Write-Host "==> Scanning dex in $apk for LLM gateway strings"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $apk))
try {
    $needles = @(
        'opencode.ai',
        'api.kilo.ai',
        'Generate command with AI'
    )
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($entry in ($zip.Entries | Where-Object { $_.FullName -like '*.dex' })) {
        $stream = $entry.Open()
        try {
            $ms = New-Object System.IO.MemoryStream
            $stream.CopyTo($ms)
            $ascii = [Text.Encoding]::ASCII.GetString($ms.ToArray())
            foreach ($needle in $needles) {
                if ($ascii.Contains($needle)) {
                    $hits.Add("$($entry.FullName): $needle")
                }
            }
        } finally {
            $stream.Dispose()
        }
    }
    if ($hits.Count -gt 0) {
        $hits | ForEach-Object { Write-Host "  HIT $_" -ForegroundColor Red }
        throw 'CLOUD_AI=false APK still contains LLM gateway strings in dex'
    }
    Write-Host '  OK: no opencode.ai / api.kilo.ai / wand label in dex'
} finally {
    $zip.Dispose()
}

$dst = Join-Path $RepoRoot 'build/app/outputs/flutter-apk/PocketShell-izzy-local.apk'
Copy-Item $apk $dst -Force
Write-Host "Izzy APK ready: $dst ($([math]::Round((Get-Item $dst).Length / 1MB, 1)) MB)" -ForegroundColor Green
