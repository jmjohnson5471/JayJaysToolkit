function Get-JJTToolMetadata {
    param([System.IO.FileInfo]$File)

    $metaPath = [IO.Path]::ChangeExtension($File.FullName, ".json")
    $relative = $File.FullName.Substring($Script:ToolsDir.Length).TrimStart('\')
    $parts = $relative -split "\\"
    $category = if ($parts.Count -gt 1) { $parts[0] } else { "Uncategorized" }

    $tool = [ordered]@{
        Name = [IO.Path]::GetFileNameWithoutExtension($File.Name)
        Category = $category
        Description = "No description provided."
        RunAsAdmin = $true
        Hidden = $false
        Arguments = ""
        ExecutionMode = "Console"
        WorkingDirectory = $File.DirectoryName
        Path = $File.FullName
        Extension = $File.Extension.ToLower()
        RelativePath = $relative
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
    Get-ChildItem -Path $Script:ToolsDir -Recurse -File |
        Where-Object { $exts -contains $_.Extension.ToLower() -and $_.Name -notlike "_*" } |
        ForEach-Object { Get-JJTToolMetadata $_ } |
        Where-Object { -not $_.Hidden } |
        Sort-Object Category, Name
}
