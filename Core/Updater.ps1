# Updater.ps1
#
# Previous behavior: silently downloaded the repo zip and wiped everything in the
# install folder except Logs/favorites.json/Cache, no confirmation, no version check,
# and no protection for any custom plugin a technician had dropped in locally.
#
# Now: checks the remote VERSION first (skips if already current), asks for
# confirmation, verifies the download actually landed before touching anything,
# backs up first, and re-copies back any plugin folder that existed locally but
# isn't part of the official download (so custom/local plugins survive an update).

function Get-JJTRemoteVersion {
    . (Join-Path $Script:BaseDir "Core\Config.ps1")
    $user = $Script:JJT_Config.GitHubUser
    $repo = $Script:JJT_Config.RepoName
    $branch = $Script:JJT_Config.Branch
    $versionUrl = "https://raw.githubusercontent.com/$user/$repo/$branch/VERSION"

    try {
        return (Invoke-WebRequest -Uri $versionUrl -UseBasicParsing -TimeoutSec 10).Content.Trim()
    } catch {
        Write-JJTLog "Could not check remote version: $($_.Exception.Message)" -Level Warn
        return $null
    }
}

function Invoke-JJTUpdate {
    . (Join-Path $Script:BaseDir "Core\Config.ps1")
    $user = $Script:JJT_Config.GitHubUser
    $repo = $Script:JJT_Config.RepoName
    $branch = $Script:JJT_Config.Branch

    $localVersionFile = Join-Path $Script:BaseDir "VERSION"
    $localVersion = if (Test-Path $localVersionFile) { (Get-Content $localVersionFile -Raw).Trim() } else { "unknown" }
    $remoteVersion = Get-JJTRemoteVersion

    if ($remoteVersion -and $remoteVersion -eq $localVersion) {
        [System.Windows.Forms.MessageBox]::Show(
            "You're already on the latest version ($localVersion).",
            "JayJaysToolkit - Up to Date",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }

    $versionText = if ($remoteVersion) { "$localVersion -> $remoteVersion" } else { "$localVersion -> (unknown, could not reach GitHub to check)" }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Update JayJaysToolkit?`n`nVersion: $versionText`n`nAny custom plugins you've added locally will be preserved. Built-in tools/plugins will be replaced with the latest from GitHub.",
        "JayJaysToolkit - Confirm Update",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $zipUrl = "https://github.com/$user/$repo/archive/refs/heads/$branch.zip"
    $work = Join-Path $env:TEMP "JayJaysToolkit_Update"
    $zip = Join-Path $env:TEMP "JayJaysToolkit_Update.zip"
    $backup = Join-Path $env:TEMP ("JayJaysToolkit_Backup_" + (Get-Date -Format yyyyMMddHHmmss))

    try {
        Write-JJTLog "Update started: $versionText"

        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $work | Out-Null

        Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing -ErrorAction Stop

        if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 1KB) {
            throw "Downloaded update file looks invalid (missing or too small). Aborting before touching the install."
        }

        Expand-Archive -Path $zip -DestinationPath $work -Force -ErrorAction Stop
        $extracted = Get-ChildItem $work -Directory | Select-Object -First 1
        if (-not $extracted) { throw "Could not find extracted repository folder inside the downloaded update." }
        if (-not (Test-Path (Join-Path $extracted.FullName "Core\GUI.ps1"))) {
            throw "Downloaded update doesn't look like a valid JayJaysToolkit release (Core\GUI.ps1 missing). Aborting."
        }

        # Figure out which local plugin folders are NOT part of the official update —
        # those are the technician's own custom plugins and must survive the update.
        $localPluginsPath = Join-Path $Script:BaseDir "Plugins"
        $newPluginsPath = Join-Path $extracted.FullName "Plugins"
        $customPluginBackup = Join-Path $backup "CustomPlugins"

        if ((Test-Path $localPluginsPath) -and (Test-Path $newPluginsPath)) {
            $officialPluginNames = (Get-ChildItem $newPluginsPath -Directory).Name
            $customPlugins = Get-ChildItem $localPluginsPath -Directory -ErrorAction SilentlyContinue |
                Where-Object { $officialPluginNames -notcontains $_.Name }

            if ($customPlugins) {
                New-Item -ItemType Directory -Force -Path $customPluginBackup | Out-Null
                foreach ($cp in $customPlugins) {
                    Copy-Item $cp.FullName (Join-Path $customPluginBackup $cp.Name) -Recurse -Force
                }
            }
        }

        # Full safety backup of the current install before we touch anything.
        Copy-Item $Script:BaseDir $backup -Recurse -Force -ErrorAction SilentlyContinue

        Get-ChildItem $Script:BaseDir -Force |
            Where-Object { $_.Name -notin @("Logs", "favorites.json", "Cache") } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

        Copy-Item "$($extracted.FullName)\*" $Script:BaseDir -Recurse -Force

        # Restore any custom plugins that weren't part of the official download.
        if (Test-Path $customPluginBackup) {
            $restoredPluginsPath = Join-Path $Script:BaseDir "Plugins"
            New-Item -ItemType Directory -Force -Path $restoredPluginsPath | Out-Null
            Get-ChildItem $customPluginBackup -Directory | ForEach-Object {
                Copy-Item $_.FullName (Join-Path $restoredPluginsPath $_.Name) -Recurse -Force
            }
            Write-JJTLog "Restored $((Get-ChildItem $customPluginBackup -Directory).Count) custom plugin(s) after update."
        }

        Write-JJTLog "Update completed successfully: $versionText"
        [System.Windows.Forms.MessageBox]::Show("Update complete. Restart JayJaysToolkit.", "JayJaysToolkit") | Out-Null
    } catch {
        Write-JJTLog "Update FAILED: $($_.Exception.Message)" -Level Error
        if (Test-Path $backup) {
            Get-ChildItem $backup -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne "CustomPlugins" } |
                ForEach-Object { Copy-Item $_.FullName $Script:BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
        [System.Windows.Forms.MessageBox]::Show("Update failed. Rollback was attempted.`n`n$($_.Exception.Message)", "JayJaysToolkit", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
}
