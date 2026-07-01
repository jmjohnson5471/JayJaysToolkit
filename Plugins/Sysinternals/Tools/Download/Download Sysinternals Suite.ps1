$ErrorActionPreference = "Stop"

$BaseDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$PortableRoot = Join-Path $BaseDir "PortableApps\Sysinternals"
$ZipPath = Join-Path $env:TEMP "SysinternalsSuite.zip"
$Url = "https://download.sysinternals.com/files/SysinternalsSuite.zip"

New-Item -ItemType Directory -Force -Path $PortableRoot | Out-Null

Write-Host "JayJaysToolkit - Sysinternals Suite"
Write-Host "Download URL: $Url"
Write-Host "Install folder: $PortableRoot"
Write-Host ""

try {
    Write-Host "Downloading Sysinternals Suite..."
    Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing

    Write-Host "Extracting..."
    Expand-Archive -Path $ZipPath -DestinationPath $PortableRoot -Force

    Write-Host ""
    Write-Host "Sysinternals Suite is ready." -ForegroundColor Green
    Write-Host $PortableRoot
    Start-Process explorer.exe $PortableRoot
}
catch {
    Write-Host ""
    Write-Host "Download/extract failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Read-Host "Press Enter to close"
