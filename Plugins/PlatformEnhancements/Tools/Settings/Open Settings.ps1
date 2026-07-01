$ErrorActionPreference = "Continue"

$ToolPath = $MyInvocation.MyCommand.Path
$BaseDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ToolPath)))
$SettingsDir = Join-Path $BaseDir "Config"
$SettingsFile = Join-Path $SettingsDir "settings.json"
New-Item -ItemType Directory -Force -Path $SettingsDir | Out-Null

if (!(Test-Path $SettingsFile)) {
    $default = [ordered]@{
        GitHub = [ordered]@{
            User = ""
            Repository = "JayJaysToolkit"
            Branch = "main"
        }
        PortableApps = [ordered]@{
            Path = "PortableApps"
            AutoUpdate = $false
        }
        Backup = [ordered]@{
            DefaultPath = ""
        }
        UI = [ordered]@{
            Theme = "Dark"
            ShowDashboardOnStart = $false
        }
    }
    $default | ConvertTo-Json -Depth 6 | Set-Content $SettingsFile -Encoding UTF8
}

Clear-Host
Write-Host "JayJaysToolkit Settings" -ForegroundColor Green
Write-Host "Settings file:"
Write-Host $SettingsFile
Write-Host ""
Get-Content $SettingsFile
Write-Host ""
Write-Host "Opening settings folder..."
Start-Process explorer.exe $SettingsDir
Read-Host "Press Enter to close"
