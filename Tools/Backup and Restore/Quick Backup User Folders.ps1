$dest = Join-Path $env:USERPROFILE "Desktop\QuickBackup_$env:COMPUTERNAME"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
foreach ($f in "Desktop","Documents","Downloads","Pictures") {
    $src = Join-Path $env:USERPROFILE $f
    if (Test-Path $src) {
        robocopy $src (Join-Path $dest $f) /E /R:1 /W:1 /XJ /FFT
    }
}
Write-Host "Quick backup saved to $dest" -ForegroundColor Green
