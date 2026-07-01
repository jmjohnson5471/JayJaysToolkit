$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$folder = Join-Path $base "Templates"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
Start-Process explorer.exe $folder
Write-Host "Opened Templates folder:"
Write-Host $folder
