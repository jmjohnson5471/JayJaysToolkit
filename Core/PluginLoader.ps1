function Get-JJTPlugins {
    $pluginRoot = Join-Path $Script:BaseDir "Plugins"
    if (!(Test-Path $pluginRoot)) { return @() }

    Get-ChildItem $pluginRoot -Directory | ForEach-Object {
        $manifest = Join-Path $_.FullName "plugin.json"
        if (Test-Path $manifest) {
            try {
                $p = Get-Content $manifest -Raw | ConvertFrom-Json
                [PSCustomObject]@{
                    Id = $p.Id
                    Name = $p.Name
                    Version = $p.Version
                    Description = $p.Description
                    Author = $p.Author
                    Enabled = if ($null -eq $p.Enabled) { $true } else { [bool]$p.Enabled }
                    Path = $_.FullName
                    ToolsPath = Join-Path $_.FullName "Tools"
                }
            } catch {}
        }
    } | Where-Object Enabled | Sort-Object Name
}

function Get-JJTToolMetadata {
    param([System.IO.FileInfo]$File,[object]$Plugin)

    $metaPath = [IO.Path]::ChangeExtension($File.FullName, ".json")
    $relative = $File.FullName.Substring($Plugin.ToolsPath.Length).TrimStart('\')
    $parts = $relative -split "\\"
    $category = if ($parts.Count -gt 1) { $parts[0] } else { $Plugin.Name }

    $tool = [ordered]@{
        Name = [IO.Path]::GetFileNameWithoutExtension($File.Name)
        Category = $category
        Plugin = $Plugin.Name
        PluginId = $Plugin.Id
        Description = "No description provided."
        RunAsAdmin = $true
        Hidden = $false
        Arguments = ""
        ExecutionMode = "Console"
        WorkingDirectory = $File.DirectoryName
        Path = $File.FullName
        Extension = $File.Extension.ToLower()
        RelativePath = Join-Path $Plugin.Id $relative
    }

    if (Test-Path $metaPath) {
        try {
            $m = Get-Content $metaPath -Raw | ConvertFrom-Json
            foreach ($prop in $m.PSObject.Properties.Name) {
                if ($tool.Contains($prop)) { $tool[$prop] = $m.$prop }
            }
        } catch {}
    }

    return [PSCustomObject]$tool
}

function Get-JJTTools {
    $exts = ".ps1",".bat",".cmd",".exe",".msi",".url"
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
