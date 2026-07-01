# JayJaysToolkit Start Script
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Gui = Join-Path $BaseDir "Core\GUI.ps1"

if (!(Test-Path $Gui)) {
    Write-Host "Missing Core\GUI.ps1" -ForegroundColor Red
    pause
    exit 1
}

& $Gui
