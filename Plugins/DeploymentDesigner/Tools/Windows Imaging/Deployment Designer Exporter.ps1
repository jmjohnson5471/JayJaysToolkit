$ErrorActionPreference = "Continue"

function Read-Default {
    param(
        [string]$Prompt,
        [string]$Default
    )
    $answer = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer
}

function Read-YesNo {
    param(
        [string]$Prompt,
        [bool]$Default = $true
    )
    $defaultText = if ($Default) { "Y" } else { "N" }
    $answer = Read-Host "$Prompt Y/N [$defaultText]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return ($answer -match "^[Yy]")
}

function XmlEscape {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return [System.Security.SecurityElement]::Escape($Text)
}

function Add-FirstLogonCommand {
    param(
        [System.Collections.Generic.List[object]]$Commands,
        [string]$Description,
        [string]$Command
    )

    $Commands.Add([PSCustomObject]@{
        Order = $Commands.Count + 1
        Description = $Description
        Command = $Command
    })
}

function Build-FirstLogonXml {
    param([System.Collections.Generic.List[object]]$Commands)

    if ($Commands.Count -eq 0) { return "" }

    $xml = "      <FirstLogonCommands>`r`n"
    foreach ($cmd in $Commands) {
        $xml += "        <SynchronousCommand wcm:action=`"add`">`r`n"
        $xml += "          <Order>$($cmd.Order)</Order>`r`n"
        $xml += "          <Description>$(XmlEscape $cmd.Description)</Description>`r`n"
        $xml += "          <CommandLine>$(XmlEscape $cmd.Command)</CommandLine>`r`n"
        $xml += "        </SynchronousCommand>`r`n"
    }
    $xml += "      </FirstLogonCommands>`r`n"
    return $xml
}

function Build-UserXml {
    param(
        [bool]$CreateUser,
        [string]$Username,
        [string]$Password
    )

    if (-not $CreateUser) { return "" }

    $passwordXml = ""
    if (-not [string]::IsNullOrWhiteSpace($Password)) {
        $passwordXml = @"
            <Password>
              <Value>$(XmlEscape $Password)</Value>
              <PlainText>true</PlainText>
            </Password>

"@
    }

    return @"
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>$(XmlEscape $Username)</Name>
            <Group>Administrators</Group>
            <DisplayName>$(XmlEscape $Username)</DisplayName>
$passwordXml          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>

"@
}

function Build-AutoLogonXml {
    param(
        [bool]$AutoLogon,
        [string]$Username,
        [string]$Password
    )

    if (-not $AutoLogon) { return "" }
    if ([string]::IsNullOrWhiteSpace($Password)) { return "" }

    return @"
      <AutoLogon>
        <Username>$(XmlEscape $Username)</Username>
        <Enabled>true</Enabled>
        <LogonCount>1</LogonCount>
        <Password>
          <Value>$(XmlEscape $Password)</Value>
          <PlainText>true</PlainText>
        </Password>
      </AutoLogon>

"@
}

function Build-UnattendXml {
    param(
        [string]$Edition,
        [string]$Arch,
        [string]$Locale,
        [string]$Keyboard,
        [string]$TimeZone,
        [string]$ComputerName,
        [string]$ProductKey,
        [bool]$HideEula,
        [bool]$HideOnline,
        [bool]$BypassNetwork,
        [bool]$SkipMachine,
        [bool]$SkipUser,
        [bool]$CreateUser,
        [string]$Username,
        [string]$Password,
        [bool]$AutoLogon,
        [System.Collections.Generic.List[object]]$Commands
    )

    $productKeyXml = ""
    if (-not [string]::IsNullOrWhiteSpace($ProductKey)) {
        $productKeyXml = @"
        <ProductKey>
          <Key>$(XmlEscape $ProductKey)</Key>
          <WillShowUI>OnError</WillShowUI>
        </ProductKey>

"@
    }

    $computerNameXml = ""
    if (-not [string]::IsNullOrWhiteSpace($ComputerName)) {
        $computerNameXml = "      <ComputerName>$(XmlEscape $ComputerName)</ComputerName>`r`n"
    }

    $userXml = Build-UserXml -CreateUser $CreateUser -Username $Username -Password $Password
    $autoLogonXml = Build-AutoLogonXml -AutoLogon $AutoLogon -Username $Username -Password $Password
    $firstLogonXml = Build-FirstLogonXml -Commands $Commands

@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="$(XmlEscape $Arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>$(XmlEscape $Locale)</UILanguage>
      </SetupUILanguage>
      <InputLocale>$(XmlEscape $Keyboard)</InputLocale>
      <SystemLocale>$(XmlEscape $Locale)</SystemLocale>
      <UILanguage>$(XmlEscape $Locale)</UILanguage>
      <UserLocale>$(XmlEscape $Locale)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="$(XmlEscape $Arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
$productKeyXml      <ImageInstall>
        <OSImage>
          <InstallFrom>
            <MetaData wcm:action="add">
              <Key>/IMAGE/NAME</Key>
              <Value>$(XmlEscape $Edition)</Value>
            </MetaData>
          </InstallFrom>
          <InstallToAvailablePartition>true</InstallToAvailablePartition>
        </OSImage>
      </ImageInstall>
      <UserData>
        <AcceptEula>true</AcceptEula>
      </UserData>
    </component>
  </settings>

  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="$(XmlEscape $Arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
$computerNameXml      <TimeZone>$(XmlEscape $TimeZone)</TimeZone>
    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="$(XmlEscape $Arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$(XmlEscape $Keyboard)</InputLocale>
      <SystemLocale>$(XmlEscape $Locale)</SystemLocale>
      <UILanguage>$(XmlEscape $Locale)</UILanguage>
      <UserLocale>$(XmlEscape $Locale)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="$(XmlEscape $Arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>$($HideEula.ToString().ToLower())</HideEULAPage>
        <HideOnlineAccountScreens>$($HideOnline.ToString().ToLower())</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>$($BypassNetwork.ToString().ToLower())</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
        <SkipMachineOOBE>$($SkipMachine.ToString().ToLower())</SkipMachineOOBE>
        <SkipUserOOBE>$($SkipUser.ToString().ToLower())</SkipUserOOBE>
      </OOBE>
$userXml$autoLogonXml$firstLogonXml    </component>
  </settings>
</unattend>
"@
}

Clear-Host
Write-Host "====================================================" -ForegroundColor Green
Write-Host " JayJaysToolkit Deployment Designer v2" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "This version exports autounattend.xml directly from PowerShell."
Write-Host "No browser download behavior is required."
Write-Host ""

$template = Read-Default "Template: Business, Home, Kiosk, OSDCloud" "Business"

switch -Regex ($template) {
    "Home" {
        $defaultEdition = "Windows 11 Home"
        $defaultEnableRdp = $false
        $defaultToolkit = $false
    }
    "Kiosk" {
        $defaultEdition = "Windows 11 Pro"
        $defaultEnableRdp = $true
        $defaultToolkit = $false
    }
    "OSD" {
        $defaultEdition = "Windows 11 Pro"
        $defaultEnableRdp = $true
        $defaultToolkit = $true
    }
    default {
        $defaultEdition = "Windows 11 Pro"
        $defaultEnableRdp = $true
        $defaultToolkit = $false
    }
}

$edition = Read-Default "Windows image name/edition" $defaultEdition
$arch = Read-Default "Architecture" "amd64"
$locale = Read-Default "Locale" "en-US"
$keyboard = Read-Default "Keyboard/input locale" "0409:00000409"
$timezone = Read-Default "Time zone" "Eastern Standard Time"
$computerName = Read-Default "Computer name, optional" ""
$productKey = Read-Default "Product key, optional" ""

Write-Host ""
Write-Host "OOBE Options" -ForegroundColor Green
$hideEula = Read-YesNo "Hide/accept EULA" $true
$hideOnline = Read-YesNo "Hide online account screens" $true
$bypassNetwork = Read-YesNo "Bypass network requirement" $true
$skipMachine = Read-YesNo "Skip machine OOBE" $true
$skipUser = Read-YesNo "Skip user OOBE" $false

Write-Host ""
Write-Host "Local Admin" -ForegroundColor Green
$createUser = Read-YesNo "Create local admin" $true
$username = "Admin"
$password = ""
$autoLogon = $false

if ($createUser) {
    $username = Read-Default "Local admin username" "Admin"
    $password = Read-Default "Local admin password, optional" ""
    $autoLogon = Read-YesNo "Auto-logon once, only works if password is set" $false
}

Write-Host ""
Write-Host "First Logon Actions" -ForegroundColor Green
$commands = New-Object System.Collections.Generic.List[object]

if ($bypassNetwork) {
    Add-FirstLogonCommand $commands "Bypass network requirement" 'reg add HKLM\SYSTEM\Setup\LabConfig /v BypassNRO /t REG_DWORD /d 1 /f'
}

if (Read-YesNo "Disable consumer features / suggested apps" $true) {
    Add-FirstLogonCommand $commands "Disable consumer features" 'reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f'
}

if (Read-YesNo "Enable Remote Desktop" $defaultEnableRdp) {
    Add-FirstLogonCommand $commands "Enable Remote Desktop" 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ItemProperty ''HKLM:\System\CurrentControlSet\Control\Terminal Server'' -Name fDenyTSConnections -Value 0; Enable-NetFirewallRule -DisplayGroup ''Remote Desktop''"'
}

if (Read-YesNo "Add JayJaysToolkit install reminder command" $defaultToolkit) {
    Add-FirstLogonCommand $commands "JayJaysToolkit install reminder" 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host ''Run JayJaysToolkit: irm https://raw.githubusercontent.com/jmjohnson5471/JayJaysToolkit/main/install.ps1 | iex''"'
}

if (Read-YesNo "Add Chris Titus utility reminder command" $false) {
    Add-FirstLogonCommand $commands "Chris Titus utility reminder" 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host ''Optional: irm https://christitus.com/win | iex''"'
}

$custom = Read-Default "Custom first-logon PowerShell command, optional" ""
if (-not [string]::IsNullOrWhiteSpace($custom)) {
    Add-FirstLogonCommand $commands "Custom PowerShell command" ("powershell -NoProfile -ExecutionPolicy Bypass -Command `"$custom`"")
}

$xml = Build-UnattendXml `
    -Edition $edition `
    -Arch $arch `
    -Locale $locale `
    -Keyboard $keyboard `
    -TimeZone $timezone `
    -ComputerName $computerName `
    -ProductKey $productKey `
    -HideEula $hideEula `
    -HideOnline $hideOnline `
    -BypassNetwork $bypassNetwork `
    -SkipMachine $skipMachine `
    -SkipUser $skipUser `
    -CreateUser $createUser `
    -Username $username `
    -Password $password `
    -AutoLogon $autoLogon `
    -Commands $commands

Write-Host ""
Write-Host "Output Location" -ForegroundColor Green
$desktop = [Environment]::GetFolderPath("Desktop")
if (!(Test-Path $desktop)) { $desktop = $env:TEMP }

$defaultOutDir = Join-Path $desktop "JayJaysDeployment"
$outDir = Read-Default "Output folder" $defaultOutDir
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$outXml = Join-Path $outDir "autounattend.xml"
$outProfile = Join-Path $outDir "deployment-profile.json"
$outPlan = Join-Path $outDir "deployment-plan.txt"

$xml | Set-Content $outXml -Encoding UTF8

$profile = [ordered]@{
    Template = $template
    Edition = $edition
    Architecture = $arch
    Locale = $locale
    Keyboard = $keyboard
    TimeZone = $timezone
    ComputerName = $computerName
    ProductKeySupplied = (-not [string]::IsNullOrWhiteSpace($productKey))
    HideEula = $hideEula
    HideOnlineAccountScreens = $hideOnline
    BypassNetworkRequirement = $bypassNetwork
    SkipMachineOOBE = $skipMachine
    SkipUserOOBE = $skipUser
    CreateLocalAdmin = $createUser
    LocalAdminUsername = $username
    LocalAdminPasswordSupplied = (-not [string]::IsNullOrWhiteSpace($password))
    AutoLogonOnce = $autoLogon
    FirstLogonCommands = $commands
}

$profile | ConvertTo-Json -Depth 5 | Set-Content $outProfile -Encoding UTF8

$plan = @()
$plan += "JayJaysToolkit Deployment Plan"
$plan += "Generated: $(Get-Date)"
$plan += ""
$plan += "Edition: $edition"
$plan += "Locale: $locale"
$plan += "Time Zone: $timezone"
$plan += "Computer Name: $computerName"
$plan += "Create Local Admin: $createUser"
$plan += "Username: $username"
$plan += ""
$plan += "First Logon Commands:"
foreach ($cmd in $commands) {
    $plan += "$($cmd.Order). $($cmd.Description)"
    $plan += "   $($cmd.Command)"
}
$plan += ""
$plan += "Next Steps:"
$plan += "1. Copy autounattend.xml to the root of your Windows install USB."
$plan += "2. Test in a VM before production."
$plan += "3. Do not commit generated XML with passwords/product keys to a public repo."

$plan | Set-Content $outPlan -Encoding UTF8

Write-Host ""
Write-Host "Export complete:" -ForegroundColor Green
Write-Host $outXml
Write-Host $outProfile
Write-Host $outPlan
Write-Host ""
Start-Process explorer.exe $outDir
Read-Host "Press Enter to close"
