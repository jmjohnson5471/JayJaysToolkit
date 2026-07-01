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
Write-Host " JayJaysToolkit - Full Backup Migration"
Write-Host "========================================="
Write-Host ""

$defaultRoot = Join-Path $env:USERPROFILE "Desktop\JayJaysBackup_$env:COMPUTERNAME"
$backupRoot = Read-Host "Backup destination folder [`"$defaultRoot`"]"
if ([string]::IsNullOrWhiteSpace($backupRoot)) { $backupRoot = $defaultRoot }

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
$log = Join-Path $backupRoot "BackupLog.txt"

"JayJaysToolkit Backup" | Out-File $log
"Computer: $env:COMPUTERNAME" | Out-File $log -Append
"User: $env:USERNAME" | Out-File $log -Append
"Date: $(Get-Date)" | Out-File $log -Append
"Destination: $backupRoot" | Out-File $log -Append

Write-Host "Creating system reports..."
try { Get-ComputerInfo | Out-File (Join-Path $backupRoot "ComputerInfo.txt") } catch {}
try { systeminfo | Out-File (Join-Path $backupRoot "SystemInfo.txt") } catch {}
try { ipconfig /all | Out-File (Join-Path $backupRoot "Network_ipconfig_all.txt") } catch {}
try { Get-NetIPConfiguration | Format-List * | Out-File (Join-Path $backupRoot "Network_NetIPConfiguration.txt") } catch {}
try { Get-Printer | Format-List * | Out-File (Join-Path $backupRoot "Printers.txt") } catch {}
try { manage-bde -status | Out-File (Join-Path $backupRoot "BitLocker_Status.txt") } catch {}

Write-Host "Creating installed software report..."
try {
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                     HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
        Where-Object DisplayName |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
        Sort-Object DisplayName |
        Export-Csv (Join-Path $backupRoot "InstalledSoftware.csv") -NoTypeInformation
} catch {}

Write-Host "Exporting Wi-Fi profiles..."
$wifiDir = Join-Path $backupRoot "WiFiProfiles"
New-Item -ItemType Directory -Force -Path $wifiDir | Out-Null
try { netsh wlan export profile key=clear folder="$wifiDir" | Tee-Object -FilePath $log -Append } catch {}

Write-Host "Exporting drivers..."
$driverDir = Join-Path $backupRoot "Drivers"
New-Item -ItemType Directory -Force -Path $driverDir | Out-Null
try { dism /online /export-driver /destination:"$driverDir" | Tee-Object -FilePath $log -Append } catch {}

Write-Host "Backing up user folders..."
$userBackup = Join-Path $backupRoot "UserData"
New-Item -ItemType Directory -Force -Path $userBackup | Out-Null

$folders = "Desktop","Documents","Downloads","Pictures","Videos","Music","Favorites"
foreach ($f in $folders) {
    $src = Join-Path $env:USERPROFILE $f
    $dst = Join-Path $userBackup $f
    Write-Host "Backing up $f..."
    Copy-FolderSafe $src $dst
}

Write-Host "Backing up browser bookmarks/profile data..."
$browserRoot = Join-Path $backupRoot "BrowserData"
New-Item -ItemType Directory -Force -Path $browserRoot | Out-Null

$items = @(
    @{Source="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks"; Dest="$browserRoot\Chrome\Default\Bookmarks"},
    @{Source="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"; Dest="$browserRoot\Chrome\Default\Preferences"},
    @{Source="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks"; Dest="$browserRoot\Edge\Default\Bookmarks"},
    @{Source="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences"; Dest="$browserRoot\Edge\Default\Preferences"}
)
foreach ($i in $items) {
    if (Test-Path $i.Source) {
        New-Item -ItemType Directory -Force -Path (Split-Path $i.Dest -Parent) | Out-Null
        Copy-Item $i.Source $i.Dest -Force -ErrorAction SilentlyContinue
    }
}
if (Test-Path "$env:APPDATA\Mozilla\Firefox\Profiles") {
    Copy-FolderSafe "$env:APPDATA\Mozilla\Firefox\Profiles" "$browserRoot\Firefox\Profiles"
}

$full = Read-Host "Copy full user profile too? This can take a while. Y/N"
if ($full -match "^[Yy]") {
    $fullDest = Join-Path $backupRoot "FullUserProfile"
    New-Item -ItemType Directory -Force -Path $fullDest | Out-Null
    robocopy $env:USERPROFILE $fullDest /E /R:1 /W:1 /XJ /FFT /XD `
        "$env:USERPROFILE\AppData\Local\Temp" `
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache" `
        "$env:USERPROFILE\AppData\Local\Packages" `
        "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps"
}

"Backup completed: $(Get-Date)" | Out-File $log -Append

Write-Host ""
Write-Host "Backup complete:" -ForegroundColor Green
Write-Host $backupRoot
Write-Host ""
