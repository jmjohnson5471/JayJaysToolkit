$ErrorActionPreference = "Continue"


function Get-JJTBaseDirFromTool {
    param([string]$StartingPath)

    if ([string]::IsNullOrWhiteSpace($StartingPath)) {
        $StartingPath = $PSScriptRoot
    }

    if ([string]::IsNullOrWhiteSpace($StartingPath)) {
        $StartingPath = Split-Path -Parent $PSCommandPath
    }

    if ([string]::IsNullOrWhiteSpace($StartingPath)) {
        $StartingPath = (Get-Location).Path
    }

    $current = $StartingPath

    while (-not [string]::IsNullOrWhiteSpace($current)) {
        if ((Test-Path (Join-Path $current "Plugins")) -and (Test-Path (Join-Path $current "Core"))) {
            return $current
        }

        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
            break
        }

        $current = $parent
    }

    # Fallback for:
    # Base\Plugins\PluginName\Tools\Category\Tool.ps1
    $fallback = $StartingPath
    for ($i = 0; $i -lt 4; $i++) {
        if ([string]::IsNullOrWhiteSpace($fallback)) { break }
        $fallback = Split-Path -Parent $fallback
    }

    return $fallback
}



        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }

    # Fallback for normal plugin path:
    # Base\Plugins\PluginName\Tools\Category\Tool.ps1
    return Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))))
}


$ToolPath = $PSCommandPath
$BaseDir = Get-JJTBaseDirFromTool -StartingPath $PSScriptRoot
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
