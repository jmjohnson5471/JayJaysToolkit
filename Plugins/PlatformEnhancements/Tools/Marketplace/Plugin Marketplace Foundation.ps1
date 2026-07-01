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
$MarketplaceDir = Join-Path $BaseDir "Marketplace"
$Manifest = Join-Path $MarketplaceDir "marketplace.json"
New-Item -ItemType Directory -Force -Path $MarketplaceDir | Out-Null

if (!(Test-Path $Manifest)) {
    $plugins = @(
        [ordered]@{ Name="Windows Deployment"; Id="WindowsDeployment"; Description="Unattend builder, OSDCloud helpers, deployment tools."; Status="Included/Optional" },
        [ordered]@{ Name="Sysinternals"; Id="Sysinternals"; Description="Download and launch Microsoft Sysinternals tools."; Status="Included" },
        [ordered]@{ Name="Portable Apps"; Id="PortableApps"; Description="Managed portable apps folder and launchers."; Status="Included" },
        [ordered]@{ Name="Quick System Reference"; Id="QuickSystemReference"; Description="Fast computer reference screen."; Status="Optional" },
        [ordered]@{ Name="System Info Plus"; Id="SystemInfoPlus"; Description="Full HTML inventory report."; Status="Optional" },
        [ordered]@{ Name="Backup Restore"; Id="BackupRestore"; Description="Migration backup and restore tools."; Status="Included" },
        [ordered]@{ Name="Microsoft 365"; Id="Microsoft365"; Description="Office, Teams, Outlook, OneDrive repair tools."; Status="Included" },
        [ordered]@{ Name="RMM Remote Support"; Id="RMMRemoteSupport"; Description="Ninja, Tactical RMM, RustDesk helpers."; Status="Included" }
    )
    [ordered]@{
        Version = "1.0"
        Updated = (Get-Date).ToString("s")
        Plugins = $plugins
    } | ConvertTo-Json -Depth 6 | Set-Content $Manifest -Encoding UTF8
}

$data = Get-Content $Manifest -Raw | ConvertFrom-Json

Clear-Host
Write-Host "============================================================" -ForegroundColor Green
Write-Host " JayJaysToolkit - Plugin Marketplace Foundation" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "This is the local marketplace foundation."
Write-Host "Later, this can point to a GitHub-hosted marketplace manifest."
Write-Host ""
$data.Plugins | Format-Table Name,Id,Status,Description -AutoSize
Write-Host ""
Write-Host "Manifest:"
Write-Host $Manifest
Write-Host ""
Start-Process explorer.exe $MarketplaceDir
Read-Host "Press Enter to close"
