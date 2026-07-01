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
$PluginsDir = Join-Path $BaseDir "Plugins"
$desktop = [Environment]::GetFolderPath("Desktop")
if (!(Test-Path $desktop)) { $desktop = $env:TEMP }
$out = Join-Path $desktop ("JayJaysToolkit_Diagnostics_{0}.html" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

$pluginRows = New-Object System.Collections.Generic.List[object]
$toolRows = New-Object System.Collections.Generic.List[object]
$issues = New-Object System.Collections.Generic.List[object]

Get-ChildItem $PluginsDir -Directory | ForEach-Object {
    $pluginFolder = $_
    $manifest = Join-Path $pluginFolder.FullName "plugin.json"
    if (!(Test-Path $manifest)) {
        $issues.Add([PSCustomObject]@{ Type="Plugin"; Item=$pluginFolder.Name; Issue="Missing plugin.json" })
        return
    }
    try {
        $p = Get-Content $manifest -Raw | ConvertFrom-Json
        $pluginRows.Add([PSCustomObject]@{
            Id=$p.Id; Name=$p.Name; Version=$p.Version; Enabled=$p.Enabled; Path=$pluginFolder.FullName
        })
        $toolsFolder = Join-Path $pluginFolder.FullName "Tools"
        if (Test-Path $toolsFolder) {
            Get-ChildItem $toolsFolder -Recurse -File | Where-Object { $_.Extension.ToLower() -in ".ps1",".bat",".cmd",".exe",".msi",".url" } | ForEach-Object {
                $meta = [IO.Path]::ChangeExtension($_.FullName,".json")
                $hasMeta = Test-Path $meta
                if (!$hasMeta) {
                    $issues.Add([PSCustomObject]@{ Type="Tool"; Item=$_.FullName; Issue="Missing sidecar JSON" })
                }
                $toolRows.Add([PSCustomObject]@{
                    Plugin=$p.Name
                    Tool=$_.BaseName
                    Extension=$_.Extension
                    HasMetadata=$hasMeta
                    Path=$_.FullName
                })
            }
        }
    } catch {
        $issues.Add([PSCustomObject]@{ Type="Plugin"; Item=$pluginFolder.Name; Issue="Invalid plugin.json: $($_.Exception.Message)" })
    }
}

$html = @"
<html><head><title>JayJaysToolkit Diagnostics</title>
<style>body{font-family:Segoe UI;margin:30px}table{border-collapse:collapse;width:100%;margin-bottom:25px}td,th{border:1px solid #ccc;padding:8px;vertical-align:top}th{background:#eee}</style>
</head><body>
<h1>JayJaysToolkit Diagnostics</h1>
<p>Generated: $(Get-Date)</p>
<h2>Plugins</h2>
$($pluginRows | ConvertTo-Html -Fragment)
<h2>Tools</h2>
$($toolRows | ConvertTo-Html -Fragment)
<h2>Issues</h2>
$($issues | ConvertTo-Html -Fragment)
</body></html>
"@
$html | Set-Content $out -Encoding UTF8
Start-Process $out
Write-Host "Diagnostics report created:"
Write-Host $out -ForegroundColor Green
Read-Host "Press Enter to close"
