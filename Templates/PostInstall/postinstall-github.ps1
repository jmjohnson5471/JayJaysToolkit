<# 
JAYJAYs IT Platform - GitHub Post Install Script

This version downloads apps-standard.csv from your GitHub repo first,
then installs the enabled apps with winget.
#>

$ErrorActionPreference = "Continue"

$GitHubCsvUrl = "https://raw.githubusercontent.com/jmjohnson5471/JayJaysToolkit/main/Templates/PostInstall/apps-standard.csv"

$WorkDir = "$env:ProgramData\JAYJAYsITPlatform\PostInstall"
$LogDir = "$env:ProgramData\JAYJAYsITPlatform\Logs"
New-Item -ItemType Directory -Force -Path $WorkDir,$LogDir | Out-Null

$CsvPath = Join-Path $WorkDir "apps-standard.csv"
$LogFile = Join-Path $LogDir ("PostInstall_GitHub_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

Start-Transcript -Path $LogFile -Append -ErrorAction SilentlyContinue | Out-Null

Write-Log "Starting GitHub-based post-install."
Write-Log "Downloading apps-standard.csv from $GitHubCsvUrl"

try {
    Invoke-WebRequest -Uri $GitHubCsvUrl -OutFile $CsvPath -UseBasicParsing
} catch {
    Write-Log "ERROR downloading apps-standard.csv: $($_.Exception.Message)"
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

$Winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (!$Winget) {
    Write-Log "winget was not found. Apps will not install until winget is available."
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

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
