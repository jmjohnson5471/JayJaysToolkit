$ErrorActionPreference = "Stop"

$PluginRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$Html = Join-Path $PluginRoot "Web\LocalUnattendGenerator.html"

if (!(Test-Path $Html)) {
    Write-Host "Could not find local generator:" -ForegroundColor Red
    Write-Host $Html
    Read-Host "Press Enter to close"
    exit 1
}

Start-Process $Html
Write-Host "Opened Local Unattend Generator:"
Write-Host $Html -ForegroundColor Green
