#Requires -Version 5.1

<#
.SYNOPSIS
    Silently installs the standard application set and Microsoft 365.
.DESCRIPTION
    Right-click this file and choose Run with PowerShell. The script elevates
    itself, installs all standard applications without questions or pauses,
    installs Microsoft 365 through the Office Deployment Tool, writes a log,
    and exits without automatically rebooting.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Relaunch as Administrator when needed. Windows will show the normal UAC prompt.
$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)
$IsAdministrator = $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdministrator) {
    try {
        $Arguments = @(
            '-NoProfile'
            '-ExecutionPolicy', 'Bypass'
            '-File', ('"{0}"' -f $PSCommandPath)
        )

        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $Arguments
        exit
    }
    catch {
        Write-Host 'Administrator elevation was declined or failed.' -ForegroundColor Red
        exit 1
    }
}

$LogDirectory = Join-Path $env:ProgramData 'JAYJAY\Logs'
$LogFile = Join-Path $LogDirectory 'StandardAppsInstall.log'
$OfficeInstallPath = Join-Path $env:TEMP 'Office365Install'
$Failures = New-Object System.Collections.Generic.List[string]

New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null

try {
    Start-Transcript -Path $LogFile -Append -Force | Out-Null
}
catch {
    Write-Host "Unable to start transcript logging: $($_.Exception.Message)" -ForegroundColor Yellow
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Text)

    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor Cyan
}

function Test-WinGetAvailable {
    $Command = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
    if ($Command) {
        return $true
    }

    $WindowsApps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    return (Test-Path $WindowsApps)
}

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )

    Write-Host "Installing $Name..." -ForegroundColor White

    $Arguments = @(
        'install'
        '--id', $Id
        '--exact'
        '--source', 'winget'
        '--silent'
        '--accept-package-agreements'
        '--accept-source-agreements'
        '--disable-interactivity'
    )

    try {
        $Process = Start-Process -FilePath 'winget.exe' -ArgumentList $Arguments -Wait -PassThru -NoNewWindow

        # WinGet can return a nonzero code when the requested package is already installed.
        if ($Process.ExitCode -eq 0) {
            Write-Host "$Name completed successfully." -ForegroundColor Green
            return $true
        }

        Write-Host "$Name returned WinGet exit code $($Process.ExitCode). Checking whether it is installed..." -ForegroundColor Yellow

        $ListOutput = & winget.exe list --id $Id --exact --accept-source-agreements 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $ListOutput -match [regex]::Escape($Id)) {
            Write-Host "$Name is already installed." -ForegroundColor Green
            return $true
        }

        Write-Host "$Name failed to install." -ForegroundColor Red
        $Failures.Add("$Name (WinGet exit code $($Process.ExitCode))")
        return $false
    }
    catch {
        Write-Host "$Name failed: $($_.Exception.Message)" -ForegroundColor Red
        $Failures.Add("$Name ($($_.Exception.Message))")
        return $false
    }
}

function Invoke-FileDownload {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination,
        [int]$Attempts = 3
    )

    $Parent = Split-Path -Path $Destination -Parent
    if ($Parent) {
        New-Item -Path $Parent -ItemType Directory -Force | Out-Null
    }

    for ($Attempt = 1; $Attempt -le $Attempts; $Attempt++) {
        try {
            Write-Host "Downloading $Url (attempt $Attempt of $Attempts)..."
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -MaximumRedirection 10

            if ((Test-Path $Destination) -and ((Get-Item $Destination).Length -gt 0)) {
                return $Destination
            }
        }
        catch {
            Write-Host "Download attempt $Attempt failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        Remove-Item -Path $Destination -Force -ErrorAction SilentlyContinue
        if ($Attempt -lt $Attempts) {
            Start-Sleep -Seconds 5
        }
    }

    throw "Failed to download $Url"
}

function Get-OfficeDeploymentToolUrl {
    $DownloadPage = 'https://www.microsoft.com/en-us/download/details.aspx?id=49117'

    for ($Attempt = 1; $Attempt -le 3; $Attempt++) {
        try {
            $Page = Invoke-WebRequest -Uri $DownloadPage -UseBasicParsing -MaximumRedirection 10
            $Link = $Page.Links |
                Where-Object { $_.href -match 'officedeploymenttool.*\.exe' } |
                Select-Object -ExpandProperty href -First 1

            if ($Link) {
                return $Link
            }
        }
        catch {
            Write-Host "Unable to read the Office Deployment Tool page on attempt ${Attempt}: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        if ($Attempt -lt 3) {
            Start-Sleep -Seconds 5
        }
    }

    throw 'Unable to locate the current Office Deployment Tool download.'
}

function Test-Microsoft365Installed {
    $RegistryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $OfficeEntry = Get-ItemProperty -Path $RegistryPaths -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -match 'Microsoft 365' -or
            $_.DisplayName -match 'Microsoft Office 365'
        } |
        Select-Object -First 1

    if ($OfficeEntry) {
        return $true
    }

    return (Test-Path "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE")
}

function Install-Microsoft365 {
    Write-Section 'Installing Microsoft 365 with the Office Deployment Tool'

    if (Test-Microsoft365Installed) {
        Write-Host 'Microsoft 365 is already installed. Skipping Office installation.' -ForegroundColor Green
        return $true
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Remove-Item -Path $OfficeInstallPath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $OfficeInstallPath -ItemType Directory -Force | Out-Null

        $ConfigurationPath = Join-Path $OfficeInstallPath 'OfficeInstall.xml'
        $OdtInstallerPath = Join-Path $OfficeInstallPath 'ODTSetup.exe'

        $OfficeXml = @'
<Configuration ID="76b3b530-54a8-44d8-9689-278ec2547592">
  <Info Description="Standard Microsoft 365 installation" />
  <Add OfficeClientEdition="64" Channel="MonthlyEnterprise" MigrateArch="TRUE">
    <Product ID="O365BusinessRetail">
      <Language ID="MatchOS" />
      <Language ID="MatchPreviousMSI" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="Publisher" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Updates Enabled="TRUE" />
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
  <Setting Id="SETUP_REBOOT" Value="Never" />
  <Setting Id="REBOOT" Value="ReallySuppress" />
</Configuration>
'@

        Set-Content -Path $ConfigurationPath -Value $OfficeXml -Encoding UTF8 -Force

        $OdtUrl = Get-OfficeDeploymentToolUrl
        Invoke-FileDownload -Url $OdtUrl -Destination $OdtInstallerPath | Out-Null

        Write-Host 'Extracting the Office Deployment Tool...'
        $Extract = Start-Process -FilePath $OdtInstallerPath `
            -ArgumentList "/quiet /extract:`"$OfficeInstallPath`"" `
            -Wait -PassThru -NoNewWindow

        if ($Extract.ExitCode -ne 0) {
            throw "Office Deployment Tool extraction returned exit code $($Extract.ExitCode)."
        }

        $SetupPath = Join-Path $OfficeInstallPath 'setup.exe'
        if (-not (Test-Path $SetupPath)) {
            throw 'Office Deployment Tool setup.exe was not found after extraction.'
        }

        Write-Host 'Downloading and installing Microsoft 365. This may take several minutes...'
        $OfficeInstall = Start-Process -FilePath $SetupPath `
            -ArgumentList "/configure `"$ConfigurationPath`"" `
            -Wait -PassThru -NoNewWindow

        if ($OfficeInstall.ExitCode -ne 0) {
            throw "Microsoft 365 setup returned exit code $($OfficeInstall.ExitCode)."
        }

        if (-not (Test-Microsoft365Installed)) {
            throw 'Microsoft 365 setup finished, but Microsoft 365 was not detected.'
        }

        Write-Host 'Microsoft 365 installed successfully.' -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Microsoft 365 installation failed: $($_.Exception.Message)" -ForegroundColor Red
        $Failures.Add("Microsoft 365 ($($_.Exception.Message))")
        return $false
    }
    finally {
        Remove-Item -Path $OfficeInstallPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

try {
    Clear-Host
    $Host.UI.RawUI.WindowTitle = 'Standard Application Installer - Administrator'

    Write-Section 'Installing Standard Applications'

    if (-not (Test-WinGetAvailable)) {
        throw 'WinGet is not available. Install or update Microsoft App Installer, then run this script again.'
    }

    Write-Host 'Updating WinGet sources...'
    & winget.exe source update --disable-interactivity 2>&1 | ForEach-Object { Write-Host $_ }

    $Applications = @(
        @{ Id = 'Adobe.Acrobat.Reader.64-bit';  Name = 'Adobe Acrobat Reader' }
        @{ Id = 'VideoLAN.VLC';                 Name = 'VLC Media Player' }
        @{ Id = 'Google.Chrome';                Name = 'Google Chrome' }
        @{ Id = 'Mozilla.Firefox';              Name = 'Mozilla Firefox' }
        @{ Id = '7zip.7zip';                    Name = '7-Zip' }
        @{ Id = 'Microsoft.VCRedist.2015+.x64'; Name = 'Microsoft Visual C++ 2015-2022 x64' }
        @{ Id = 'Microsoft.DotNet.Runtime.8';   Name = '.NET Runtime 8' }
        @{ Id = 'Microsoft.DotNet.Runtime.9';   Name = '.NET Runtime 9' }
        @{ Id = 'Microsoft.DotNet.Runtime.10';  Name = '.NET Runtime 10' }
        @{ Id = 'Notepad++.Notepad++';          Name = 'Notepad++' }
    )

    foreach ($Application in $Applications) {
        Install-WinGetPackage -Id $Application.Id -Name $Application.Name | Out-Null
    }

    Install-Microsoft365 | Out-Null

    Write-Section 'Installation Finished'

    if ($Failures.Count -eq 0) {
        Write-Host 'All standard applications completed successfully.' -ForegroundColor Green
        $ExitCode = 0
    }
    else {
        Write-Host 'The installer finished, but these items need attention:' -ForegroundColor Yellow
        foreach ($Failure in $Failures) {
            Write-Host " - $Failure" -ForegroundColor Yellow
        }
        $ExitCode = 1
    }

    Write-Host "Log file: $LogFile" -ForegroundColor Gray
}
catch {
    Write-Host "Fatal installer error: $($_.Exception.Message)" -ForegroundColor Red
    $ExitCode = 1
}
finally {
    try {
        Stop-Transcript | Out-Null
    }
    catch {
    }
}

exit $ExitCode
