$ErrorActionPreference = "Continue"

$ToolPath = $MyInvocation.MyCommand.Path
$BaseDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ToolPath)))
$PluginsDir = Join-Path $BaseDir "Plugins"

Clear-Host
Write-Host "============================================================" -ForegroundColor Green
Write-Host " JayJaysToolkit - Plugin Manager" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

$plugins = Get-ChildItem $PluginsDir -Directory | ForEach-Object {
    $manifest = Join-Path $_.FullName "plugin.json"
    if (Test-Path $manifest) {
        try {
            $p = Get-Content $manifest -Raw | ConvertFrom-Json
            $toolCount = 0
            $toolsFolder = Join-Path $_.FullName "Tools"
            if (Test-Path $toolsFolder) {
                $toolCount = (Get-ChildItem $toolsFolder -Recurse -File |
                    Where-Object { $_.Extension.ToLower() -in ".ps1",".bat",".cmd",".exe",".msi",".url" -and $_.Name -notlike "_*" } |
                    Measure-Object).Count
            }
            [PSCustomObject]@{
                Enabled = if ($null -eq $p.Enabled) { $true } else { [bool]$p.Enabled }
                Id = $p.Id
                Name = $p.Name
                Version = $p.Version
                Tools = $toolCount
                Path = $_.FullName
                Description = $p.Description
            }
        } catch {
            [PSCustomObject]@{
                Enabled = $false
                Id = $_.Name
                Name = $_.Name
                Version = "ERROR"
                Tools = 0
                Path = $_.FullName
                Description = "Invalid plugin.json"
            }
        }
    }
}

$plugins | Sort-Object Name | Format-Table Enabled,Name,Version,Tools,Description -AutoSize

Write-Host ""
Write-Host "Options:" -ForegroundColor Green
Write-Host "  O = Open Plugins folder"
Write-Host "  R = Create plugin report HTML"
Write-Host "  Q = Quit"
Write-Host ""

$choice = Read-Host "Choose"
switch ($choice.ToUpper()) {
    "O" { Start-Process explorer.exe $PluginsDir }
    "R" {
        $desktop = [Environment]::GetFolderPath("Desktop")
        if (!(Test-Path $desktop)) { $desktop = $env:TEMP }
        $out = Join-Path $desktop ("JayJaysToolkit_PluginReport_{0}.html" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
        $html = @"
<html><head><title>JayJaysToolkit Plugin Report</title>
<style>body{font-family:Segoe UI;margin:30px}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:8px}th{background:#eee}</style>
</head><body><h1>JayJaysToolkit Plugin Report</h1>
<p>Generated: $(Get-Date)</p>
$($plugins | Sort-Object Name | ConvertTo-Html -Fragment)
</body></html>
"@
        $html | Set-Content $out -Encoding UTF8
        Start-Process $out
    }
}
