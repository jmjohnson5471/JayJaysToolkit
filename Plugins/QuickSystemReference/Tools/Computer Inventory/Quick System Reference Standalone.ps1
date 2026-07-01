$ErrorActionPreference = "Continue"

function Get-WindowsDisplayVersion {
    try {
        $cv = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        if ($cv.DisplayVersion) { return $cv.DisplayVersion }
        if ($cv.ReleaseId) { return $cv.ReleaseId }
        return "Unknown"
    } catch { return "Unknown" }
}

function Get-FullProductKey {
    try {
        $key = (Get-CimInstance -ClassName SoftwareLicensingService).OA3xOriginalProductKey
        if ([string]::IsNullOrWhiteSpace($key)) { return "Not detected" }
        return $key
    } catch { return "Not detected" }
}

function Get-ActivationStatus {
    try {
        $lic = Get-CimInstance SoftwareLicensingProduct |
            Where-Object { $_.PartialProductKey -and $_.LicenseStatus -eq 1 } |
            Select-Object -First 1
        if ($lic) { return "Activated" }
        return "Not activated / unknown"
    } catch { return "Unknown" }
}

function Get-SecureBootStatus {
    try { return (Confirm-SecureBootUEFI).ToString() }
    catch { return "Unavailable / Legacy BIOS" }
}

function Get-TPMQuick {
    try {
        $tpm = Get-Tpm
        if ($tpm.TpmPresent -and $tpm.TpmReady) { return "Present and Ready" }
        if ($tpm.TpmPresent) { return "Present but not ready" }
        return "Not present"
    } catch { return "Unknown" }
}

function Get-BitLockerQuick {
    try {
        $vol = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
        return "$($vol.ProtectionStatus) / $($vol.VolumeStatus) / $($vol.EncryptionPercentage)%"
    } catch {
        try {
            $raw = manage-bde -status C: 2>$null | Out-String
            $prot = ($raw -split "`n" | Where-Object { $_ -match "Protection Status" } | Select-Object -First 1).Trim()
            if ($prot) { return $prot }
            return "Unknown"
        } catch { return "Unknown" }
    }
}

function Get-PublicIP {
    try {
        return (Invoke-RestMethod "https://api.ipify.org" -TimeoutSec 5)
    } catch {
        return "Skipped/unavailable"
    }
}

function Get-Info {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $ip = Get-NetIPConfiguration | Where-Object IPv4DefaultGateway | Select-Object -First 1
    $uptime = (Get-Date) - $os.LastBootUpTime

    $ipv4 = ""
    $gw = ""
    $dns = ""
    $adapter = ""

    if ($ip) {
        $adapter = $ip.InterfaceAlias
        $ipv4 = ($ip.IPv4Address.IPAddress -join ", ")
        $gw = $ip.IPv4DefaultGateway.NextHop
        $dns = ($ip.DNSServer.ServerAddresses -join ", ")
    }

    [ordered]@{
        "Computer Name" = $env:COMPUTERNAME
        "Logged In User" = "$env:USERDOMAIN\$env:USERNAME"
        "OS" = $os.Caption
        "Windows Version" = Get-WindowsDisplayVersion
        "Windows Build" = $os.BuildNumber
        "Product Key" = Get-FullProductKey
        "Activation" = Get-ActivationStatus
        "Manufacturer" = $cs.Manufacturer
        "Model" = $cs.Model
        "Serial Number" = $bios.SerialNumber
        "BIOS Version" = $bios.SMBIOSBIOSVersion
        "CPU" = $cpu.Name
        "RAM" = "{0:N1} GB" -f ($cs.TotalPhysicalMemory / 1GB)
        "C Drive Size" = "{0:N1} GB" -f ($disk.Size / 1GB)
        "C Drive Free" = "{0:N1} GB" -f ($disk.FreeSpace / 1GB)
        "Domain/Workgroup" = $cs.Domain
        "Domain Joined" = $cs.PartOfDomain
        "Secure Boot" = Get-SecureBootStatus
        "TPM" = Get-TPMQuick
        "BitLocker C" = Get-BitLockerQuick
        "Network Adapter" = $adapter
        "IPv4" = $ipv4
        "Gateway" = $gw
        "DNS" = $dns
        "Last Boot" = $os.LastBootUpTime
        "Uptime" = "{0} days, {1} hours" -f [int]$uptime.TotalDays,$uptime.Hours
    }
}

function Convert-InfoToText {
    param([hashtable]$Info)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("JayJaysToolkit - Quick System Reference")
    $lines.Add("Generated: $(Get-Date)")
    $lines.Add("")
    foreach ($key in $Info.Keys) {
        $lines.Add(("{0,-18}: {1}" -f $key,$Info[$key]))
    }
    return ($lines -join [Environment]::NewLine)
}

function Write-StatusLine {
    param([string]$Label,[string]$Value)

    $good = @("Activated","True","Present and Ready")
    $bad = @("Not activated","False","Not present","Unavailable")

    $color = "White"
    foreach ($g in $good) { if ($Value -like "$g*") { $color = "Green" } }
    foreach ($b in $bad) { if ($Value -like "$b*") { $color = "Yellow" } }

    Write-Host ("{0,-18}: " -f $Label) -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor $color
}

function Show-Reference {
    param([hashtable]$Info)

    Clear-Host
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host " JayJaysToolkit - Quick System Reference" -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host ""

    foreach ($key in $Info.Keys) {
        if ($key -in @("Activation","Domain Joined","Secure Boot","TPM","BitLocker C")) {
            Write-StatusLine $key $Info[$key]
        } else {
            Write-Host ("{0,-18}: " -f $key) -NoNewline -ForegroundColor DarkGray
            Write-Host $Info[$key]
        }
    }

    Write-Host ""
    Write-Host "Options:" -ForegroundColor Green
    Write-Host "  C = Copy to clipboard"
    Write-Host "  E = Export to TXT on Desktop"
    Write-Host "  P = Show public IP"
    Write-Host "  R = Refresh"
    Write-Host "  Q = Quit"
    Write-Host ""
}

do {
    $info = Get-Info
    Show-Reference $info
    $choice = Read-Host "Choose"

    switch ($choice.ToUpper()) {
        "C" {
            $text = Convert-InfoToText $info
            Set-Clipboard -Value $text
            Write-Host "Copied to clipboard." -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        "E" {
            $desktop = [Environment]::GetFolderPath("Desktop")
            if (!(Test-Path $desktop)) { $desktop = $env:TEMP }
            $out = Join-Path $desktop ("QuickSystemReference_{0}_{1}.txt" -f $env:COMPUTERNAME,(Get-Date -Format "yyyyMMdd_HHmmss"))
            Convert-InfoToText $info | Set-Content $out -Encoding UTF8
            Write-Host "Exported to: $out" -ForegroundColor Green
            Start-Process explorer.exe "/select,`"$out`""
            Start-Sleep -Seconds 2
        }
        "P" {
            Write-Host ""
            Write-Host ("Public IP         : {0}" -f (Get-PublicIP)) -ForegroundColor Cyan
            Read-Host "Press Enter to continue"
        }
        "R" { }
        "Q" { break }
        default {
            Write-Host "Invalid option."
            Start-Sleep -Seconds 1
        }
    }
} while ($choice.ToUpper() -ne "Q")
