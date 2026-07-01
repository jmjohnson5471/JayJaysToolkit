# Full Backup Migration
# Captures a full "before you touch this machine" snapshot: system info, installed
# software, drivers, Wi-Fi profiles, user data folders, and browser bookmarks.

$ErrorActionPreference = "Continue"

function Copy-FolderSafe {
    param([string]$Source, [string]$Destination)
    if (Test-Path $Source) {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        robocopy $Source $Destination /E /R:1 /W:1 /XJ /FFT /COPY:DAT /DCOPY:DAT
    }
}

Clear-Host
Write-Host "JayJaysToolkit Full Backup Migration" -ForegroundColor Green

$default = Join-Path $env:USERPROFILE "Desktop\JayJaysBackup_$env:COMPUTERNAME"
$backupRoot = Read-Host "Backup destination folder [`"$default`"]"
if ([string]::IsNullOrWhiteSpace($backupRoot)) { $backupRoot = $default }
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$log = Join-Path $backupRoot "BackupLog.txt"
"JayJaysToolkit Backup $(Get-Date)" | Out-File $log

# --- System info snapshot ---
Get-ComputerInfo | Out-File (Join-Path $backupRoot "ComputerInfo.txt") -ErrorAction SilentlyContinue
ipconfig /all | Out-File (Join-Path $backupRoot "Network_ipconfig_all.txt")
Get-Printer | Format-List * | Out-File (Join-Path $backupRoot "Printers.txt") -ErrorAction SilentlyContinue
manage-bde -status | Out-File (Join-Path $backupRoot "BitLocker_Status.txt") -ErrorAction SilentlyContinue

Get-ItemProperty `
    HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, `
    HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
    -ErrorAction SilentlyContinue |
    Where-Object DisplayName |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Sort-Object DisplayName |
    Export-Csv (Join-Path $backupRoot "InstalledSoftware.csv") -NoTypeInformation

# --- Wi-Fi profiles (includes saved passwords) ---
$wifiDir = Join-Path $backupRoot "WiFiProfiles"
New-Item -ItemType Directory -Force -Path $wifiDir | Out-Null
netsh wlan export profile key=clear folder="$wifiDir" | Out-File $log -Append

# --- Drivers ---
$driverDir = Join-Path $backupRoot "Drivers"
New-Item -ItemType Directory -Force -Path $driverDir | Out-Null
dism /online /export-driver /destination:"$driverDir" | Out-File $log -Append

# --- User data folders ---
$userBackup = Join-Path $backupRoot "UserData"
New-Item -ItemType Directory -Force -Path $userBackup | Out-Null
foreach ($f in "Desktop", "Documents", "Downloads", "Pictures", "Videos", "Music", "Favorites") {
    Copy-FolderSafe (Join-Path $env:USERPROFILE $f) (Join-Path $userBackup $f)
}

# --- Browser bookmarks ---
$browserRoot = Join-Path $backupRoot "BrowserData"
New-Item -ItemType Directory -Force -Path $browserRoot | Out-Null

$browserBookmarks = @(
    @{ Source = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks";  Dest = "$browserRoot\Chrome\Default\Bookmarks" }
    @{ Source = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"; Dest = "$browserRoot\Edge\Default\Bookmarks" }
)
foreach ($b in $browserBookmarks) {
    if (Test-Path $b.Source) {
        New-Item -ItemType Directory -Force -Path (Split-Path $b.Dest -Parent) | Out-Null
        Copy-Item $b.Source $b.Dest -Force
    }
}
if (Test-Path "$env:APPDATA\Mozilla\Firefox\Profiles") {
    Copy-FolderSafe "$env:APPDATA\Mozilla\Firefox\Profiles" "$browserRoot\Firefox\Profiles"
}

Write-Host "Backup complete: $backupRoot" -ForegroundColor Green
Read-Host "Press Enter to close"
