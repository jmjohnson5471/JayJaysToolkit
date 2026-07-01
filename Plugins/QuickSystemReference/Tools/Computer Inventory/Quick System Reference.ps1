
$ErrorActionPreference = "SilentlyContinue"

function Get-RegValue {
    param([string]$Path,[string]$Name)
    try { (Get-ItemProperty -Path $Path -Name $Name).$Name } catch { "" }
}

function Get-ActualWindowsName {
    param([int]$Build,[string]$Edition)

    $family = if ($Build -ge 22000) { "Windows 11" } else { "Windows 10" }

    $editionFriendly = switch -Regex ($Edition) {
        "Professional" { "Pro"; break }
        "Enterprise"   { "Enterprise"; break }
        "Education"    { "Education"; break }
        "Core"         { "Home"; break }
        default        { if ($Edition) { $Edition } else { "" } }
    }

    return "$family $editionFriendly".Trim()
}

function Get-WindowsVersion {
    $display = Get-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "DisplayVersion"
    if ([string]::IsNullOrWhiteSpace($display)) {
        $display = Get-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" "ReleaseId"
    }
    if ([string]::IsNullOrWhiteSpace($display)) { "Unknown" } else { $display }
}

function Get-FullProductKey {
    try {
        $key = (Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey
        if ([string]::IsNullOrWhiteSpace($key)) { "Not detected" } else { $key }
    } catch { "Not detected" }
}

function Get-ActivationStatus {
    try {
        $lic = Get-CimInstance SoftwareLicensingProduct |
            Where-Object { $_.PartialProductKey -and $_.LicenseStatus -eq 1 } |
            Select-Object -First 1
        if ($lic) { "Activated" } else { "Not activated / unknown" }
    } catch { "Unknown" }
}

function Get-LicenseChannel {
    try {
        $lic = Get-CimInstance SoftwareLicensingProduct |
            Where-Object { $_.PartialProductKey -and $_.Name -match "Windows" } |
            Select-Object -First 1
        if ($lic.Description) { $lic.Description } else { "Unknown" }
    } catch { "Unknown" }
}

function Get-SecureBootStatus {
    try {
        if (Confirm-SecureBootUEFI) { "Enabled" } else { "Disabled" }
    } catch { "Unavailable / Legacy BIOS" }
}

function Get-TPMStatus {
    try {
        $t = Get-Tpm
        if ($t.TpmPresent -and $t.TpmReady) { "Present and Ready" }
        elseif ($t.TpmPresent) { "Present but not ready" }
        else { "Not present" }
    } catch { "Unknown" }
}

function Get-BitLockerStatus {
    try {
        $b = Get-BitLockerVolume -MountPoint "C:"
        "$($b.ProtectionStatus) / $($b.VolumeStatus) / $($b.EncryptionPercentage)%"
    } catch {
        $raw = manage-bde -status C: 2>$null | Out-String
        $prot = ($raw -split "`n" | Where-Object { $_ -match "Protection Status" } | Select-Object -First 1).Trim()
        $conv = ($raw -split "`n" | Where-Object { $_ -match "Conversion Status" } | Select-Object -First 1).Trim()
        if ($prot -or $conv) { "$prot $conv" } else { "Unknown" }
    }
}

function Get-DefenderQuick {
    try {
        $d = Get-MpComputerStatus
        if ($d.AntivirusEnabled -and $d.RealTimeProtectionEnabled) { "Enabled / Real-Time On" }
        elseif ($d.AntivirusEnabled) { "Enabled / Real-Time Off" }
        else { "Disabled" }
    } catch { "Unknown" }
}

function Get-RebootPending {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return "Pending" } }
    return "No"
}

function Get-Color {
    param([string]$Value)
    if ($Value -match "Activated|Enabled|Ready|True|On|No$|Fully|Present and Ready") { return "Green" }
    if ($Value -match "Pending|Not activated|Disabled|Unavailable|Unknown|Off|Not present") { return "Yellow" }
    return "White"
}

function Write-Line {
    param([string]$Label,[string]$Value,[string]$Color = "White")
    Write-Host ("{0,-20}: " -f $Label) -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor $Color
}

Clear-Host

$cvPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$rawBuild = Get-RegValue $cvPath "CurrentBuild"
$ubr = Get-RegValue $cvPath "UBR"
$edition = Get-RegValue $cvPath "EditionID"
$installDate = Get-RegValue $cvPath "InstallDate"
$buildInt = 0
[int]::TryParse($rawBuild, [ref]$buildInt) | Out-Null
$buildFull = if ($ubr -ne "") { "$rawBuild.$ubr" } else { "$rawBuild" }

$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$os = Get-CimInstance Win32_OperatingSystem
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$ipConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -or $_.IPv4Address } | Select-Object -First 1
$adapter = if ($ipConfig) { $ipConfig.InterfaceAlias } else { "" }
$ipv4 = if ($ipConfig.IPv4Address) { ($ipConfig.IPv4Address.IPAddress -join ", ") } else { "" }
$gateway = if ($ipConfig.IPv4DefaultGateway) { $ipConfig.IPv4DefaultGateway.NextHop } else { "" }
$dns = if ($ipConfig.DNSServer.ServerAddresses) { ($ipConfig.DNSServer.ServerAddresses -join ", ") } else { "" }

$uptime = (Get-Date) - $os.LastBootUpTime

$windowsName = Get-ActualWindowsName -Build $buildInt -Edition $edition
$version = Get-WindowsVersion
$key = Get-FullProductKey
$activation = Get-ActivationStatus
$channel = Get-LicenseChannel
$secureBoot = Get-SecureBootStatus
$tpm = Get-TPMStatus
$bitlocker = Get-BitLockerStatus
$defender = Get-DefenderQuick
$reboot = Get-RebootPending

Write-Host "================================================================" -ForegroundColor Green
Write-Host " JayJaysToolkit - Quick System Reference v3" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Operating System" -ForegroundColor Green
Write-Line "Windows" $windowsName
Write-Line "Version" $version
Write-Line "Build" $buildFull
Write-Line "Architecture" $os.OSArchitecture
Write-Line "Installed" ([DateTimeOffset]::FromUnixTimeSeconds([int64]$installDate).DateTime.ToString("yyyy-MM-dd HH:mm:ss"))
Write-Line "Activation" $activation (Get-Color $activation)
Write-Line "License Channel" $channel
Write-Line "Product Key" $key "Cyan"

Write-Host ""
Write-Host "Hardware" -ForegroundColor Green
Write-Line "Computer Name" $env:COMPUTERNAME
Write-Line "Logged In User" "$env:USERDOMAIN\$env:USERNAME"
Write-Line "Manufacturer" $cs.Manufacturer
Write-Line "Model" $cs.Model
Write-Line "Serial Number" $bios.SerialNumber
Write-Line "BIOS Version" $bios.SMBIOSBIOSVersion
Write-Line "CPU" $cpu.Name
Write-Line "RAM" ("{0:N1} GB" -f ($cs.TotalPhysicalMemory / 1GB))
if ($disk) {
    Write-Line "C: Size" ("{0:N1} GB" -f ($disk.Size / 1GB))
    Write-Line "C: Free" ("{0:N1} GB" -f ($disk.FreeSpace / 1GB))
}

Write-Host ""
Write-Host "Security / Health" -ForegroundColor Green
Write-Line "Domain" $cs.Domain
Write-Line "Domain Joined" ([string]$cs.PartOfDomain) (Get-Color ([string]$cs.PartOfDomain))
Write-Line "Secure Boot" $secureBoot (Get-Color $secureBoot)
Write-Line "TPM" $tpm (Get-Color $tpm)
Write-Line "BitLocker C" $bitlocker (Get-Color $bitlocker)
Write-Line "Defender" $defender (Get-Color $defender)
Write-Line "Reboot Pending" $reboot (Get-Color $reboot)
Write-Line "Last Boot" ([string]$os.LastBootUpTime)
Write-Line "Uptime" ("{0} days, {1} hours" -f [int]$uptime.TotalDays,$uptime.Hours)

Write-Host ""
Write-Host "Network" -ForegroundColor Green
Write-Line "Adapter" $adapter
Write-Line "IPv4" $ipv4
Write-Line "Gateway" $gateway
Write-Line "DNS" $dns

$lines = @(
"JayJaysToolkit - Quick System Reference v3",
"Generated: $(Get-Date)",
"",
"Windows          : $windowsName",
"Version          : $version",
"Build            : $buildFull",
"Architecture     : $($os.OSArchitecture)",
"Activation       : $activation",
"License Channel  : $channel",
"Product Key      : $key",
"",
"Computer Name    : $env:COMPUTERNAME",
"Logged In User   : $env:USERDOMAIN\$env:USERNAME",
"Manufacturer     : $($cs.Manufacturer)",
"Model            : $($cs.Model)",
"Serial Number    : $($bios.SerialNumber)",
"BIOS Version     : $($bios.SMBIOSBIOSVersion)",
"CPU              : $($cpu.Name)",
"RAM              : $('{0:N1} GB' -f ($cs.TotalPhysicalMemory / 1GB))",
"C: Size          : $('{0:N1} GB' -f ($disk.Size / 1GB))",
"C: Free          : $('{0:N1} GB' -f ($disk.FreeSpace / 1GB))",
"",
"Domain           : $($cs.Domain)",
"Domain Joined    : $($cs.PartOfDomain)",
"Secure Boot      : $secureBoot",
"TPM              : $tpm",
"BitLocker C      : $bitlocker",
"Defender         : $defender",
"Reboot Pending   : $reboot",
"Last Boot        : $($os.LastBootUpTime)",
"Uptime           : $('{0} days, {1} hours' -f [int]$uptime.TotalDays,$uptime.Hours)",
"",
"Network Adapter  : $adapter",
"IPv4             : $ipv4",
"Gateway          : $gateway",
"DNS              : $dns"
)

Write-Host ""
Write-Host "Options" -ForegroundColor Green
Write-Host "  C = Copy to clipboard"
Write-Host "  E = Export to TXT on Desktop"
Write-Host "  Q = Quit"
Write-Host ""

$choice = Read-Host "Choose"
switch ($choice.ToUpper()) {
    "C" {
        $lines -join [Environment]::NewLine | Set-Clipboard
        Write-Host "Copied to clipboard." -ForegroundColor Green
        Start-Sleep -Seconds 1
    }
    "E" {
        $desktop = [Environment]::GetFolderPath("Desktop")
        if (!(Test-Path $desktop)) { $desktop = $env:TEMP }
        $out = Join-Path $desktop ("QuickSystemReference_{0}_{1}.txt" -f $env:COMPUTERNAME,(Get-Date -Format "yyyyMMdd_HHmmss"))
        $lines | Set-Content $out -Encoding UTF8
        Write-Host "Exported to: $out" -ForegroundColor Green
        Start-Process explorer.exe "/select,`"$out`""
        Start-Sleep -Seconds 2
    }
}
