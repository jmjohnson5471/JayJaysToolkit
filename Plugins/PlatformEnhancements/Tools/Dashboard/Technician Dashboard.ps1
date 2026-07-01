$ErrorActionPreference = "SilentlyContinue"

function Get-RegValue {
    param([string]$Path,[string]$Name)
    try { (Get-ItemProperty -Path $Path -Name $Name).$Name } catch { "" }
}

function Get-ActualWindowsName {
    $cv = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $build = [int](Get-RegValue $cv "CurrentBuild")
    $edition = Get-RegValue $cv "EditionID"
    $family = if ($build -ge 22000) { "Windows 11" } else { "Windows 10" }
    $friendly = switch -Regex ($edition) {
        "Professional" { "Pro"; break }
        "Enterprise" { "Enterprise"; break }
        "Education" { "Education"; break }
        "Core" { "Home"; break }
        default { $edition }
    }
    "$family $friendly"
}

function Get-DisplayVersion {
    $cv = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $v = Get-RegValue $cv "DisplayVersion"
    if (!$v) { $v = Get-RegValue $cv "ReleaseId" }
    if (!$v) { "Unknown" } else { $v }
}

function Get-Activation {
    try {
        $lic = Get-CimInstance SoftwareLicensingProduct |
            Where-Object { $_.PartialProductKey -and $_.LicenseStatus -eq 1 } |
            Select-Object -First 1
        if ($lic) { "OK: Activated" } else { "WARN: Not activated / unknown" }
    } catch { "WARN: Unknown" }
}

function Get-SecureBoot {
    try { if (Confirm-SecureBootUEFI) { "OK: Enabled" } else { "WARN: Disabled" } }
    catch { "WARN: Unavailable / Legacy BIOS" }
}

function Get-TPM {
    try {
        $t = Get-Tpm
        if ($t.TpmPresent -and $t.TpmReady) { "OK: Present and Ready" }
        elseif ($t.TpmPresent) { "WARN: Present but not ready" }
        else { "WARN: Not present" }
    } catch { "WARN: Unknown" }
}

function Get-BitLocker {
    try {
        $b = Get-BitLockerVolume -MountPoint "C:"
        if ($b.ProtectionStatus -eq "On") { "OK: On / $($b.VolumeStatus) / $($b.EncryptionPercentage)%" }
        else { "WARN: Off / $($b.VolumeStatus) / $($b.EncryptionPercentage)%" }
    } catch { "WARN: Unknown" }
}

function Get-Defender {
    try {
        $d = Get-MpComputerStatus
        if ($d.AntivirusEnabled -and $d.RealTimeProtectionEnabled) { "OK: Enabled / Real-Time On" }
        elseif ($d.AntivirusEnabled) { "WARN: Enabled / Real-Time Off" }
        else { "WARN: Disabled" }
    } catch { "WARN: Unknown" }
}

function Get-RebootPending {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return "WARN: Pending" } }
    "OK: No"
}

function Write-Status {
    param([string]$Label,[string]$Value)
    $color = "White"
    if ($Value -like "OK:*") { $color = "Green" }
    elseif ($Value -like "WARN:*") { $color = "Yellow" }
    elseif ($Value -like "BAD:*") { $color = "Red" }
    $clean = $Value -replace "^(OK|WARN|BAD):\s*",""
    Write-Host ("{0,-20}: " -f $Label) -NoNewline -ForegroundColor DarkGray
    Write-Host $clean -ForegroundColor $color
}

Clear-Host
$cv = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$build = Get-RegValue $cv "CurrentBuild"
$ubr = Get-RegValue $cv "UBR"
$fullBuild = if ($ubr -ne "") { "$build.$ubr" } else { $build }

$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os = Get-CimInstance Win32_OperatingSystem
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$ip = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -or $_.IPv4Address } | Select-Object -First 1
$uptime = (Get-Date) - $os.LastBootUpTime

Write-Host "================================================================" -ForegroundColor Green
Write-Host " JayJaysToolkit - Technician Dashboard" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "System" -ForegroundColor Green
Write-Status "Windows" ("OK: " + (Get-ActualWindowsName))
Write-Status "Version" ("OK: " + (Get-DisplayVersion))
Write-Status "Build" ("OK: " + $fullBuild)
Write-Status "Computer Name" ("OK: " + $env:COMPUTERNAME)
Write-Status "User" ("OK: " + "$env:USERDOMAIN\$env:USERNAME")
Write-Status "Manufacturer" ("OK: " + $cs.Manufacturer)
Write-Status "Model" ("OK: " + $cs.Model)
Write-Status "Serial" ("OK: " + $bios.SerialNumber)
Write-Status "RAM" ("OK: {0:N1} GB" -f ($cs.TotalPhysicalMemory/1GB))
Write-Status "Uptime" ("OK: {0} days, {1} hours" -f [int]$uptime.TotalDays,$uptime.Hours)

Write-Host ""
Write-Host "Health" -ForegroundColor Green
Write-Status "Activation" (Get-Activation)
Write-Status "BitLocker C" (Get-BitLocker)
Write-Status "Defender" (Get-Defender)
Write-Status "Secure Boot" (Get-SecureBoot)
Write-Status "TPM" (Get-TPM)
Write-Status "Reboot Pending" (Get-RebootPending)

if ($disk) {
    $freePct = if ($disk.Size -gt 0) { [math]::Round(($disk.FreeSpace / $disk.Size) * 100,1) } else { 0 }
    $diskStatus = if ($freePct -lt 10) { "BAD: {0:N1} GB free ({1}%)" -f ($disk.FreeSpace/1GB),$freePct }
                  elseif ($freePct -lt 20) { "WARN: {0:N1} GB free ({1}%)" -f ($disk.FreeSpace/1GB),$freePct }
                  else { "OK: {0:N1} GB free ({1}%)" -f ($disk.FreeSpace/1GB),$freePct }
    Write-Status "C Drive" $diskStatus
}

Write-Host ""
Write-Host "Network" -ForegroundColor Green
if ($ip) {
    Write-Status "Adapter" ("OK: " + $ip.InterfaceAlias)
    Write-Status "IPv4" ("OK: " + ($ip.IPv4Address.IPAddress -join ", "))
    Write-Status "Gateway" ("OK: " + $ip.IPv4DefaultGateway.NextHop)
    Write-Status "DNS" ("OK: " + ($ip.DNSServer.ServerAddresses -join ", "))
} else {
    Write-Status "Network" "WARN: No active IP configuration detected"
}

Write-Host ""
Read-Host "Press Enter to close"
