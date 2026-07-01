# Quick Backup User Folders
# Backs up Desktop, Documents, Downloads, and Pictures to a destination the
# technician picks at runtime: a flash drive / any attached drive (shown in a
# numbered list), a NAS/network path, or the local default. Nothing copies
# until the chosen destination is shown back and explicitly confirmed.

Clear-Host
Write-Host "========================================================" -ForegroundColor DarkYellow
Write-Host " JayJaysToolkit - Quick Backup User Folders" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor DarkYellow
Write-Host ""

$default = Join-Path $env:USERPROFILE "Desktop\QuickBackup_$env:COMPUTERNAME"

# --- List attached drives so flash drives / external disks are pick-able by number ---
$drives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Sort-Object DeviceID
$driveMap = @{}
$i = 1

Write-Host "Available drives on this machine:" -ForegroundColor Cyan
foreach ($d in $drives) {
    $typeLabel = switch ($d.DriveType) {
        2 { "Removable (flash/USB drive)" }
        3 { "Fixed disk" }
        4 { "Network drive" }
        5 { "CD/DVD" }
        default { "Other" }
    }
    $volLabel = if ($d.VolumeName) { " - $($d.VolumeName)" } else { "" }
    $freeLabel = if ($d.FreeSpace) { "  ({0} GB free)" -f [math]::Round($d.FreeSpace / 1GB, 1) } else { "" }
    Write-Host ("  [{0}] {1}{2}   {3}{4}" -f $i, $d.DeviceID, $volLabel, $typeLabel, $freeLabel)
    $driveMap["$i"] = $d.DeviceID
    $i++
}
Write-Host ""
Write-Host "  [N] Enter a NAS/network path manually (example: \\server\share\folder)" -ForegroundColor Cyan
Write-Host "  [Enter] Use the default: $default" -ForegroundColor Cyan
Write-Host ""

# --- Pick + validate + confirm destination — loops until you actually say Y ---
$dest = $null
while (-not $dest) {
    $candidate = $null

    while (-not $candidate) {
        $choice = Read-Host "Pick a drive number, N for a network path, or press Enter for the default"

        if ([string]::IsNullOrWhiteSpace($choice)) {
            $picked = $default
        }
        elseif ($choice -match "^[Nn]$") {
            $netPath = (Read-Host "Enter the full network/NAS path").Trim('"')
            if ([string]::IsNullOrWhiteSpace($netPath)) {
                Write-Host "No path entered." -ForegroundColor Red
                continue
            }
            $picked = Join-Path $netPath "QuickBackup_$env:COMPUTERNAME"
        }
        elseif ($driveMap.ContainsKey($choice)) {
            $picked = Join-Path $driveMap[$choice] "QuickBackup_$env:COMPUTERNAME"
        }
        else {
            Write-Host "'$choice' isn't a valid option." -ForegroundColor Red
            continue
        }

        try {
            New-Item -ItemType Directory -Force -Path $picked -ErrorAction Stop | Out-Null

            # New-Item can report success on some UNC edge cases yet still fail to
            # actually write — this catches that before robocopy runs.
            $testFile = Join-Path $picked ".jjt_write_test"
            Set-Content -Path $testFile -Value "test" -ErrorAction Stop
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue

            $candidate = $picked
        } catch {
            Write-Host "Could not write to '$picked': $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "If this is a NAS path, make sure it's reachable and you have permission." -ForegroundColor Yellow
            Write-Host ""
        }
    }

    Write-Host ""
    Write-Host "Backup destination: $candidate" -ForegroundColor Green
    $confirm = Read-Host "Start backup here? (Y = go / N = pick a different destination / C = cancel)"

    if ($confirm -match "^[Yy]") {
        $dest = $candidate
    }
    elseif ($confirm -match "^[Cc]") {
        Write-Host "Backup cancelled." -ForegroundColor Yellow
        Read-Host "Press Enter to close"
        exit
    }
    else {
        Write-Host ""
        Write-Host "OK, pick a different destination." -ForegroundColor Cyan
        Write-Host ""
    }
}

Write-Host ""
foreach ($f in "Desktop", "Documents", "Downloads", "Pictures") {
    $src = Join-Path $env:USERPROFILE $f
    if (Test-Path $src) {
        robocopy $src (Join-Path $dest $f) /E /R:1 /W:1 /XJ /FFT
    }
}

Write-Host ""
Write-Host "Quick backup saved to $dest" -ForegroundColor Green
Read-Host "Press Enter to close"
