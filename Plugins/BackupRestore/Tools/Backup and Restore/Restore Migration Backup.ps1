# Restore Migration Backup
# Restores a backup created by "Full Backup Migration" onto this machine.
# NOTE: This overwrites the current user's Desktop/Documents/etc with backup content.
# The GUI already asks for confirmation before running this (see plugin.json: Confirm=true).

function Copy-FolderSafe {
    param([string]$Source, [string]$Destination)
    if (Test-Path $Source) {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        robocopy $Source $Destination /E /R:1 /W:1 /XJ /FFT /COPY:DAT /DCOPY:DAT
    }
}

Clear-Host
Write-Host "JayJaysToolkit Restore Migration Backup" -ForegroundColor Green

$backupRoot = Read-Host "Enter backup folder path"
if (-not (Test-Path $backupRoot)) {
    Write-Host "Backup folder not found." -ForegroundColor Red
    Read-Host "Press Enter"
    exit
}

# --- User data ---
$userData = Join-Path $backupRoot "UserData"
foreach ($f in "Desktop", "Documents", "Downloads", "Pictures", "Videos", "Music", "Favorites") {
    Copy-FolderSafe (Join-Path $userData $f) (Join-Path $env:USERPROFILE $f)
}

# --- Browser bookmarks (optional) ---
$browserRoot = Join-Path $backupRoot "BrowserData"
if (Test-Path $browserRoot) {
    $restoreBrowsers = Read-Host "Restore browser bookmarks/profile data? Y/N"
    if ($restoreBrowsers -match "^[Yy]") {
        taskkill /f /im chrome.exe 2>$null
        taskkill /f /im msedge.exe 2>$null
        taskkill /f /im firefox.exe 2>$null

        Copy-Item "$browserRoot\Chrome\Default\Bookmarks" "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks" -Force -ErrorAction SilentlyContinue
        Copy-Item "$browserRoot\Edge\Default\Bookmarks" "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks" -Force -ErrorAction SilentlyContinue
        Copy-FolderSafe "$browserRoot\Firefox\Profiles" "$env:APPDATA\Mozilla\Firefox\Profiles"
    }
}

# --- Wi-Fi profiles (optional) ---
$wifiDir = Join-Path $backupRoot "WiFiProfiles"
if (Test-Path $wifiDir) {
    $importWifi = Read-Host "Import Wi-Fi profiles? Y/N"
    if ($importWifi -match "^[Yy]") {
        Get-ChildItem $wifiDir -Filter *.xml | ForEach-Object {
            netsh wlan add profile filename="$($_.FullName)" user=all
        }
    }
}

# --- Drivers (manual review, not auto-installed) ---
$driverDir = Join-Path $backupRoot "Drivers"
if (Test-Path $driverDir) {
    Write-Host "Driver backup: $driverDir"
    $openDrivers = Read-Host "Open driver folder? Y/N"
    if ($openDrivers -match "^[Yy]") { explorer $driverDir }
}

Write-Host "Restore complete. Reboot recommended." -ForegroundColor Green
Read-Host "Press Enter to close"
