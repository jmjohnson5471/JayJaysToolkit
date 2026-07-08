<# 
JAYJAYs IT Platform - Standard Post Install Script

Purpose:
- Run after Windows setup from autounattend.xml
- Install standard free third-party apps from apps-standard.csv using winget
- Save logs under C:\ProgramData\JAYJAYsITPlatform\Logs

Expected files:
- postinstall.ps1
- apps-standard.csv

Recommended use:
Copy the PostInstall folder to your deployment USB or GitHub repo.
Call this script from FirstLogonCommands in autounattend.xml.
#>

$ErrorActionPreference = "Continue"

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = "$env:ProgramData\JAYJAYsITPlatform\Logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$LogFile = Join-Path $LogDir ("PostInstall_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

Start-Transcript -Path $LogFile -Append -ErrorAction SilentlyContinue | Out-Null

Write-Log "Starting JAYJAYs IT Platform post-install."

$CsvPath = Join-Path $BaseDir "apps-standard.csv"

if (!(Test-Path $CsvPath)) {
    Write-Log "ERROR: apps-standard.csv not found at $CsvPath"
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

Write-Log "Checking winget..."

$Winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (!$Winget) {
    Write-Log "winget was not found. Attempting Microsoft Store App Installer repair may be needed."
    Write-Log "Apps will not install until winget is available."
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

Write-Log "winget found at $($Winget.Source)"

try {
    winget source update | Out-Host
} catch {
    Write-Log "winget source update failed: $($_.Exception.Message)"
}

$Apps = Import-Csv $CsvPath | Where-Object { $_.Enabled -match "true|yes|1" }

foreach ($App in $Apps) {
    Write-Log "Installing $($App.Name) [$($App.Id)]"

    try {
        winget install `
            --id $App.Id `
            --exact `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity

        if ($LASTEXITCODE -eq 0) {
            Write-Log "SUCCESS: $($App.Name)"
        } else {
            Write-Log "WARNING: $($App.Name) finished with exit code $LASTEXITCODE"
        }
    } catch {
        Write-Log "ERROR installing $($App.Name): $($_.Exception.Message)"
    }
}

Write-Log "Post-install app installation complete."
Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
