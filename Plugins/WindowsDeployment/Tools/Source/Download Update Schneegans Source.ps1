$ErrorActionPreference = "Stop"

$base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$target = Join-Path $base "LocalGenerator\schneegans-unattend-generator"
$zip = Join-Path $env:TEMP "schneegans-unattend-generator.zip"
$url = "https://github.com/cschneegans/unattend-generator/archive/refs/heads/main.zip"

Write-Host "Downloading Schneegans unattend-generator source..."
Write-Host $url
Write-Host ""

Remove-Item $zip -Force -ErrorAction SilentlyContinue
Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $target | Out-Null

Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

$tmp = Join-Path $env:TEMP ("schneegans-unattend-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Expand-Archive $zip -DestinationPath $tmp -Force

$src = Get-ChildItem $tmp -Directory | Select-Object -First 1
Copy-Item "$($src.FullName)\*" $target -Recurse -Force

Write-Host "Source downloaded to:" -ForegroundColor Green
Write-Host $target
Start-Process explorer.exe $target

Read-Host "Press Enter to close"
