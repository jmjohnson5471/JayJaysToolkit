<# 
JAYJAYs IT Platform - Standard Post Install Script
FIXED: Uses separate transcript and custom log files so Add-Content does not fight Start-Transcript.
#>

$ErrorActionPreference = "Continue"

$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = "$env:ProgramData\JAYJAYsITPlatform\Logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "PostInstall_$TimeStamp.log"
$TranscriptFile = Join-Path $LogDir "PostInstall_Transcript_$TimeStamp.log"

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    try {
        [System.IO.File]::AppendAllText($LogFile, $line + [Environment]::NewLine)
    } catch {
        Write-Host "LOG WARNING: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Start-Transcript -Path $TranscriptFile -Append -ErrorAction SilentlyContinue | Out-Null

Write-Log "Starting JAYJAYs IT Platform post-install."

$GitHubCsvUrl = "https://raw.githubusercontent.com/jmjohnson5471/JayJaysToolkit/main/Templates/PostInstall/apps-standard.csv"
$WorkDir = "$env:ProgramData\JAYJAYsITPlatform\PostInstall"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$CsvPath = Join-Path $WorkDir "apps-standard.csv"
Write-Log "Downloading apps-standard.csv from $GitHubCsvUrl"
try { Invoke-WebRequest -Uri $GitHubCsvUrl -OutFile $CsvPath -UseBasicParsing } catch { Write-Log "ERROR downloading CSV: $($_.Exception.Message)"; Stop-Transcript -ErrorAction SilentlyContinue | Out-Null; exit 1 }

$Winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (!$Winget) {
    Write-Log "ERROR: winget was not found. Apps will not install until winget is available."
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

Write-Log "winget found at $($Winget.Source)"

try {
    Write-Log "Updating winget sources."
    winget source update | Out-Host
} catch {
    Write-Log "WARNING: winget source update failed: $($_.Exception.Message)"
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
Write-Log "Main log: $LogFile"
Write-Log "Transcript: $TranscriptFile"

Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
