function Get-JJTLocalVersion {
    $v = Join-Path $Script:BaseDir "VERSION"
    if (Test-Path $v) { return (Get-Content $v -Raw).Trim() }
    return "0.0.0"
}

function Invoke-JJTUpdate {
    param([switch]$Silent)

    . (Join-Path $Script:BaseDir "Core\Config.ps1")

    $user = $Script:JJT_Config.GitHubUser
    $repo = $Script:JJT_Config.RepoName
    $branch = $Script:JJT_Config.Branch

    $zipUrl = "https://github.com/$user/$repo/archive/refs/heads/$branch.zip"
    $work = Join-Path $env:TEMP "JayJaysToolkit_Update"
    $zip = Join-Path $env:TEMP "JayJaysToolkit_Update.zip"
    $backup = Join-Path $env:TEMP ("JayJaysToolkit_Backup_" + (Get-Date -Format yyyyMMddHHmmss))

    try {
        if (-not $Silent) { [System.Windows.Forms.MessageBox]::Show("Updating from GitHub...","JayJaysToolkit") | Out-Null }

        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $work | Out-Null

        Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $work -Force

        $extracted = Get-ChildItem $work -Directory | Select-Object -First 1
        if (-not $extracted) { throw "Could not find extracted repository." }

        Copy-Item $Script:BaseDir $backup -Recurse -Force -ErrorAction SilentlyContinue

        Get-ChildItem $Script:BaseDir -Force |
            Where-Object { $_.Name -notin @("Logs","favorites.json") } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

        Copy-Item "$($extracted.FullName)\*" $Script:BaseDir -Recurse -Force

        if (-not $Silent) { [System.Windows.Forms.MessageBox]::Show("Update complete. Restart JayJaysToolkit.","JayJaysToolkit") | Out-Null }
    } catch {
        if (Test-Path $backup) {
            Copy-Item "$backup\*" $Script:BaseDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        [System.Windows.Forms.MessageBox]::Show("Update failed and rollback was attempted.`n$($_.Exception.Message)","JayJaysToolkit") | Out-Null
    }
}
