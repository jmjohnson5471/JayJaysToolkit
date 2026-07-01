$ErrorActionPreference = "Continue"

function Get-JJTBaseDirFromTool {
    $current = Split-Path -Parent $MyInvocation.MyCommand.Path
    while ($current) {
        if ((Test-Path (Join-Path $current "Plugins")) -and (Test-Path (Join-Path $current "Core"))) {
            return $current
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }

    # Fallback for normal plugin path:
    # Base\Plugins\PluginName\Tools\Category\Tool.ps1
    return Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))))
}


$ToolPath = $MyInvocation.MyCommand.Path
$BaseDir = Get-JJTBaseDirFromTool
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
