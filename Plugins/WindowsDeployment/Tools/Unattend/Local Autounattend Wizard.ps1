$ErrorActionPreference = "Stop"

function Ask-Default {
    param(
        [string]$Prompt,
        [string]$Default
    )
    $v = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
    return $v
}

function Ask-YesNo {
    param(
        [string]$Prompt,
        [bool]$Default = $true
    )
    $d = if ($Default) { "Y" } else { "N" }
    $v = Read-Host "$Prompt Y/N [$d]"
    if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
    return ($v -match "^[Yy]")
}

function Escape-Xml {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return [System.Security.SecurityElement]::Escape($Text)
}

Clear-Host
Write-Host "============================================================" -ForegroundColor Green
Write-Host " JayJaysToolkit - Local Autounattend Wizard" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "This wizard runs locally. It does not send entered values to the internet." -ForegroundColor Cyan
Write-Host ""

$desktop = [Environment]::GetFolderPath("Desktop")
if (!(Test-Path $desktop)) { $desktop = $env:TEMP }

$outFolder = Ask-Default "Output folder" (Join-Path $desktop "JayJaysAutounattend")
New-Item -ItemType Directory -Force -Path $outFolder | Out-Null

$computerName = Ask-Default "Computer name pattern" "JAYJAY-PC"
$registeredOwner = Ask-Default "Registered owner" "User"
$timeZone = Ask-Default "Time zone" "Eastern Standard Time"
$locale = Ask-Default "Locale" "en-US"
$keyboard = Ask-Default "Keyboard/input locale" "en-US"

Write-Host ""
Write-Host "Windows Edition" -ForegroundColor Green
Write-Host "1) Windows 11 Pro"
Write-Host "2) Windows 11 Home"
Write-Host "3) Windows 11 Enterprise"
$editionChoice = Ask-Default "Choose edition" "1"
$edition = switch ($editionChoice) {
    "2" { "Windows 11 Home" }
    "3" { "Windows 11 Enterprise" }
    default { "Windows 11 Pro" }
}

$skipOobe = Ask-YesNo "Skip most OOBE prompts" $true
$localAdmin = Ask-Default "Local admin username" "JayAdmin"
$setPassword = Ask-YesNo "Set local admin password in XML? Not recommended for public/shared media" $false
$password = ""
if ($setPassword) {
    $secure = Read-Host "Local admin password" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
}

$enableRdp = Ask-YesNo "Enable Remote Desktop" $false
$disableConsumer = Ask-YesNo "Disable consumer features / suggestions policies" $true
$copySetupScript = Ask-YesNo "Create FirstLogonSetup.ps1 beside XML" $true

$passwordXml = ""
if ($setPassword -and $password) {
$passwordXml = @"
          <Password>
            <Value>$(Escape-Xml $password)</Value>
            <PlainText>true</PlainText>
          </Password>
"@
}

$oobeXml = if ($skipOobe) {
@"
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
"@
} else { "" }

$firstLogonCommands = @()
if ($enableRdp) {
    $firstLogonCommands += @"
        <SynchronousCommand wcm:action="add">
          <CommandLine>powershell -ExecutionPolicy Bypass -Command "Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0; Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"</CommandLine>
          <Description>Enable Remote Desktop</Description>
          <Order>1</Order>
        </SynchronousCommand>
"@
}

if ($disableConsumer) {
    $firstLogonCommands += @"
        <SynchronousCommand wcm:action="add">
          <CommandLine>powershell -ExecutionPolicy Bypass -Command "New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force; New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableWindowsConsumerFeatures -Type DWord -Value 1 -Force"</CommandLine>
          <Description>Disable consumer features</Description>
          <Order>2</Order>
        </SynchronousCommand>
"@
}

$firstLogonXml = ""
if ($firstLogonCommands.Count -gt 0) {
$firstLogonXml = @"
      <FirstLogonCommands>
$($firstLogonCommands -join "`r`n")
      </FirstLogonCommands>
"@
}

$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<!--
Generated locally by JayJaysToolkit Local Autounattend Wizard.
Values are processed on this computer.
Review before production use.
-->
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>$(Escape-Xml $locale)</UILanguage>
      </SetupUILanguage>
      <InputLocale>$(Escape-Xml $keyboard)</InputLocale>
      <SystemLocale>$(Escape-Xml $locale)</SystemLocale>
      <UILanguage>$(Escape-Xml $locale)</UILanguage>
      <UserLocale>$(Escape-Xml $locale)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ImageInstall>
        <OSImage>
          <InstallToAvailablePartition>false</InstallToAvailablePartition>
          <WillShowUI>OnError</WillShowUI>
          <InstallFrom>
            <MetaData wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
              <Key>/IMAGE/NAME</Key>
              <Value>$(Escape-Xml $edition)</Value>
            </MetaData>
          </InstallFrom>
        </OSImage>
      </ImageInstall>
      <UserData>
        <AcceptEula>true</AcceptEula>
        <FullName>$(Escape-Xml $registeredOwner)</FullName>
        <Organization>$(Escape-Xml $registeredOwner)</Organization>
      </UserData>
    </component>
  </settings>

  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>$(Escape-Xml $computerName)</ComputerName>
      <RegisteredOwner>$(Escape-Xml $registeredOwner)</RegisteredOwner>
      <TimeZone>$(Escape-Xml $timeZone)</TimeZone>
    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$(Escape-Xml $keyboard)</InputLocale>
      <SystemLocale>$(Escape-Xml $locale)</SystemLocale>
      <UILanguage>$(Escape-Xml $locale)</UILanguage>
      <UserLocale>$(Escape-Xml $locale)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
$oobeXml
      </OOBE>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <Name>$(Escape-Xml $localAdmin)</Name>
            <Group>Administrators</Group>
$passwordXml
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
$firstLogonXml
    </component>
  </settings>
</unattend>
"@

$outXml = Join-Path $outFolder "autounattend.xml"
$xml | Set-Content $outXml -Encoding UTF8

if ($copySetupScript) {
$setupScript = @"
# FirstLogonSetup.ps1
# Generated by JayJaysToolkit.
# Add your post-install commands here.

Write-Host "JayJaysToolkit first logon setup started."

# Example:
# irm https://raw.githubusercontent.com/jmjohnson5471/JayJaysToolkit/main/install.ps1 | iex
"@
    $setupScript | Set-Content (Join-Path $outFolder "FirstLogonSetup.ps1") -Encoding UTF8
}

Write-Host ""
Write-Host "Created:" -ForegroundColor Green
Write-Host $outXml
Write-Host ""
Write-Host "Review the XML before using it on production machines." -ForegroundColor Yellow
Start-Process explorer.exe $outFolder
Read-Host "Press Enter to close"
