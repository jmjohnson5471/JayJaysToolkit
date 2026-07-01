$ErrorActionPreference = "Continue"

function Copy-FolderSafe {
    param([string]$Source,[string]$Destination)
    if (Test-Path $Source) {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        robocopy $Source $Destination /E /R:1 /W:1 /XJ /FFT /COPY:DAT /DCOPY:DAT
    }
}

Clear-Host
Write-Host "========================================="
Write-Host " JayJaysToolkit - Restore Migration"
Write-Host "========================================="
Write-Host ""

$backupRoot = Read-Host "Enter backup folder path"
if (!(Test-Path $backupRoot)) {
    Write-Host "Backup folder not found." -ForegroundColor Red
    exit 1
}

$log = Join-Path $backupRoot "RestoreLog_$env:COMPUTERNAME.txt"
"JayJaysToolkit Restore" | Out-File $log
"Computer: $env:COMPUTERNAME" | Out-File $log -Append
"User: $env:USERNAME" | Out-File $log -Append
"Date: $(Get-Date)" | Out-File $log -Append
"Source: $backupRoot" | Out-File $log -Append

$userData = Join-Path $backupRoot "UserData"
if (Test-Path $userData) {
    Write-Host "Restoring user folders..."
    $folders = "Desktop","Documents","Downloads","Pictures","Videos","Music","Favorites"
    foreach ($f in $folders) {
        $src = Join-Path $userData $f
        $dst = Join-Path $env:USERPROFILE $f
        if (Test-Path $src) {
            Write-Host "Restoring $f..."
            Copy-FolderSafe $src $dst
        }
    }
} else {
    Write-Host "UserData folder not found in backup." -ForegroundColor Yellow
}

$browserRoot = Join-Path $backupRoot "BrowserData"
if (Test-Path $browserRoot) {
    $restoreBrowsers = Read-Host "Restore browser bookmarks/profile data? Y/N"
    if ($restoreBrowsers -match "^[Yy]") {
        taskkill /f /im chrome.exe 2>$null
        taskkill /f /im msedge.exe 2>$null
        taskkill /f /im firefox.exe 2>$null

        $items = @(
            @{Source="$browserRoot\Chrome\Default\Bookmarks"; Dest="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks"},
            @{Source="$browserRoot\Chrome\Default\Preferences"; Dest="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"},
            @{Source="$browserRoot\Edge\Default\Bookmarks"; Dest="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"},
            @{Source="$browserRoot\Edge\Default\Preferences"; Dest="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences"}
        )
        foreach ($i in $items) {
            if (Test-Path $i.Source) {
                New-Item -ItemType Directory -Force -Path (Split-Path $i.Dest -Parent) | Out-Null
                Copy-Item $i.Source $i.Dest -Force -ErrorAction SilentlyContinue
                Write-Host "Restored $($i.Dest)"
            }
        }

        if (Test-Path "$browserRoot\Firefox\Profiles") {
            New-Item -ItemType Directory -Force -Path "$env:APPDATA\Mozilla\Firefox\Profiles" | Out-Null
            Copy-FolderSafe "$browserRoot\Firefox\Profiles" "$env:APPDATA\Mozilla\Firefox\Profiles"
        }
    }
}

$wifiDir = Join-Path $backupRoot "WiFiProfiles"
if (Test-Path $wifiDir) {
    $restoreWifi = Read-Host "Import Wi-Fi profiles? Y/N"
    if ($restoreWifi -match "^[Yy]") {
        Get-ChildItem $wifiDir -Filter "*.xml" | ForEach-Object {
            netsh wlan add profile filename="$($_.FullName)" user=all | Tee-Object -FilePath $log -Append
        }
    }
}

$driverDir = Join-Path $backupRoot "Drivers"
if (Test-Path $driverDir) {
    Write-Host ""
    Write-Host "Driver backup found:" -ForegroundColor Green
    Write-Host $driverDir
    $open = Read-Host "Open driver folder? Y/N"
    if ($open -match "^[Yy]") { Start-Process explorer.exe $driverDir }
}

"Restore completed: $(Get-Date)" | Out-File $log -Append
Write-Host ""
Write-Host "Restore complete. Reboot recommended." -ForegroundColor Green
