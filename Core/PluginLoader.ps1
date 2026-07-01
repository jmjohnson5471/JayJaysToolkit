# PluginLoader.ps1
# Discovers plugins and tools on disk. Malformed manifests are logged (not silently
# dropped) so a technician editing a plugin.json/tool.json can actually find their typo.

function Get-JJTPlugins {
    $pluginRoot = Join-Path $Script:BaseDir "Plugins"
    if (!(Test-Path $pluginRoot)) { return @() }

    Get-ChildItem $pluginRoot -Directory | ForEach-Object {
        $manifest = Join-Path $_.FullName "plugin.json"
        if (Test-Path $manifest) {
            try {
                $p = Get-Content $manifest -Raw | ConvertFrom-Json

                if (-not $p.Id -or -not $p.Name) {
                    Write-JJTLog "Plugin manifest missing required Id/Name: $manifest" -Level Warn
                    return
                }

                [PSCustomObject]@{
                    Id          = $p.Id
                    Name        = $p.Name
                    Version     = if ($p.Version) { $p.Version } else { "0.0.0" }
                    Description = $p.Description
                    Author      = $p.Author
                    Enabled     = if ($null -eq $p.Enabled) { $true } else { [bool]$p.Enabled }
                    Path        = $_.FullName
                    ToolsPath   = Join-Path $_.FullName "Tools"
                }
            } catch {
                Write-JJTLog "Failed to parse plugin manifest '$manifest': $($_.Exception.Message)" -Level Error
            }
        }
    } | Where-Object { $_ -and $_.Enabled } | Sort-Object Name
}

function Get-JJTToolMetadata {
    param([System.IO.FileInfo]$File, [object]$Plugin)

    $metaPath = [IO.Path]::ChangeExtension($File.FullName, ".json")
    $relative = $File.FullName.Substring($Plugin.ToolsPath.Length).TrimStart('\')
    $parts = $relative -split "\\"
    $category = if ($parts.Count -gt 1) { $parts[0] } else { $Plugin.Name }

    $tool = [ordered]@{
        Name             = [IO.Path]::GetFileNameWithoutExtension($File.Name)
        Category         = $category
        Plugin           = $Plugin.Name
        PluginId         = $Plugin.Id
        Description      = "No description provided."
        RunAsAdmin       = $true
        Hidden           = $false
        Arguments        = ""
        ExecutionMode    = "Console"
        Confirm          = $false
        ConfirmMessage   = ""
        WorkingDirectory = $File.DirectoryName
        Path             = $File.FullName
        Extension        = $File.Extension.ToLower()
        RelativePath     = Join-Path $Plugin.Id $relative
    }

    if (Test-Path $metaPath) {
        try {
            $m = Get-Content $metaPath -Raw | ConvertFrom-Json
            foreach ($prop in $m.PSObject.Properties.Name) {
                if ($tool.Contains($prop)) { $tool[$prop] = $m.$prop }
            }
        } catch {
            Write-JJTLog "Failed to parse tool metadata '$metaPath': $($_.Exception.Message)" -Level Error
        }
    }

    return [PSCustomObject]$tool
}

function Get-JJTTools {
    $exts = ".ps1", ".bat", ".cmd", ".exe", ".msi", ".url"
    $plugins = @(Get-JJTPlugins)
    foreach ($plugin in $plugins) {
        if (Test-Path $plugin.ToolsPath) {
            Get-ChildItem -Path $plugin.ToolsPath -Recurse -File |
                Where-Object { $exts -contains $_.Extension.ToLower() -and $_.Name -notlike "_*" } |
                ForEach-Object { Get-JJTToolMetadata $_ $plugin } |
                Where-Object { -not $_.Hidden }
        }
    }
}
