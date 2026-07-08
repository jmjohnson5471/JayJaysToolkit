function Get-SRMPluginRoot {
    $c = $PSScriptRoot
    while ($c -and !(Test-Path (Join-Path $c "plugin.json"))) {
        $p = Split-Path -Parent $c
        if ($p -eq $c) { break }
        $c = $p
    }
    return $c
}
function Get-SRMSettings { Get-Content (Join-Path (Get-SRMPluginRoot) "Config\repository-settings.json") -Raw | ConvertFrom-Json }
function Save-SRMSettings($s) { $s | ConvertTo-Json -Depth 8 | Set-Content (Join-Path (Get-SRMPluginRoot) "Config\repository-settings.json") -Encoding UTF8 }
function Get-SRMApps { Get-Content (Join-Path (Get-SRMPluginRoot) "Config\apps-hybrid.json") -Raw | ConvertFrom-Json }
function Get-SRMProfiles { Get-ChildItem (Join-Path (Get-SRMPluginRoot) "Profiles") -Filter "*.json" | % { Get-Content $_.FullName -Raw | ConvertFrom-Json } }

function Select-SRMRepositoryPath {
    Add-Type -AssemblyName System.Windows.Forms
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select software repository folder: USB, local folder, or network share"
    if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $d.SelectedPath }
    return ""
}

function Find-SRMFlashRepos {
    $s = Get-SRMSettings
    $r = @()
    Get-PSDrive -PSProvider FileSystem | ? { $_.Root -match "^[A-Z]:\\" } | % {
        foreach ($n in $s.FlashDriveFolderNames) {
            $candidate = Join-Path $_.Root $n
            if (Test-Path $candidate) { $r += $candidate }
        }
    }
    return $r
}

function Get-SRMRepos($SelectedPath) {
    $s = Get-SRMSettings
    $repos = @()
    if ($SelectedPath -and (Test-Path $SelectedPath)) { $repos += $SelectedPath }
    $repos += @(Find-SRMFlashRepos)
    if ($s.NetworkPath -and (Test-Path $s.NetworkPath)) { $repos += $s.NetworkPath }
    if ($s.LocalPath -and (Test-Path $s.LocalPath)) { $repos += $s.LocalPath }
    return @($repos | Select-Object -Unique)
}

function Find-SRMInstaller($App, $Repos) {
    foreach ($repo in $Repos) {
        foreach ($i in $App.Installers) {
            $candidate = Join-Path $repo $i.RelativePath
            if (Test-Path $candidate) {
                return [pscustomobject]@{Path=$candidate; Arguments=$i.Arguments; RunAsAdmin=[bool]$i.RunAsAdmin; Source=$repo}
            }
        }
    }
    return $null
}

function Install-SRMApp($App, $Repos, [bool]$WingetFallback) {
    Write-Host "`nInstalling $($App.Name)" -ForegroundColor Cyan
    $local = Find-SRMInstaller $App $Repos
    if ($local) {
        Write-Host "Using local installer: $($local.Path)" -ForegroundColor Green
        if ($local.RunAsAdmin) { Start-Process $local.Path -ArgumentList $local.Arguments -Verb RunAs -Wait }
        else { Start-Process $local.Path -ArgumentList $local.Arguments -Wait }
        return
    }
    if ($WingetFallback -and $App.WingetId) {
        Write-Host "Local installer not found. Using winget: $($App.WingetId)" -ForegroundColor Yellow
        winget install --id $App.WingetId --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        return
    }
    Write-Host "No local installer and no winget fallback for $($App.Name)." -ForegroundColor Red
}

function Invoke-SRMProfileInstall {
    param([string]$ProfileName="Standard Workstation", [string]$SelectedRepositoryPath="")
    $settings = Get-SRMSettings
    $apps = Get-SRMApps
    $profile = Get-SRMProfiles | ? { $_.Name -eq $ProfileName } | Select-Object -First 1
    if (!$profile) { throw "Profile not found: $ProfileName" }
    $repos = @(Get-SRMRepos $SelectedRepositoryPath)
    Clear-Host
    Write-Host "JAYJAYs IT Platform - Software Repository Installer" -ForegroundColor Green
    Write-Host "Profile: $($profile.Name)"
    Write-Host "Repositories:"
    if ($repos.Count -eq 0) { Write-Host "  None. Winget fallback only." -ForegroundColor Yellow }
    else { $repos | % { Write-Host "  $_" } }
    foreach ($name in $profile.Apps) {
        $app = $apps | ? { $_.Name -eq $name } | Select-Object -First 1
        if ($app -and $app.Enabled) { Install-SRMApp $app $repos ([bool]$settings.AllowWingetFallback) }
        else { Write-Host "Skipping missing/disabled app: $name" -ForegroundColor Yellow }
    }
    Write-Host "`nProfile install complete." -ForegroundColor Green
}
