$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$folder = Join-Path $base "LocalGenerator"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
Start-Process explorer.exe $folder
Write-Host "Opened LocalGenerator folder:"
Write-Host $folder
