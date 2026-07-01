Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security

function Escape-Xml {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return [System.Security.SecurityElement]::Escape($Text)
}

function New-AutounattendXml {
    param(
        [string]$ComputerName,
        [string]$Owner,
        [string]$Edition,
        [string]$TimeZone,
        [string]$Locale,
        [string]$Keyboard,
        [string]$LocalAdmin,
        [string]$Password,
        [bool]$SetPassword,
        [bool]$SkipOobe,
        [bool]$EnableRdp,
        [bool]$DisableConsumer,
        [bool]$InstallToolkit,
        [string]$ToolkitInstallCommand
    )

    $passwordXml = ""
    if ($SetPassword -and $Password) {
$passwordXml = @"
          <Password>
            <Value>$(Escape-Xml $Password)</Value>
            <PlainText>true</PlainText>
          </Password>
"@
    }

    $oobeXml = if ($SkipOobe) {
@"
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
"@
    } else { "" }

    $commands = New-Object System.Collections.Generic.List[string]
    $order = 1

    if ($EnableRdp) {
        $commands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>powershell -ExecutionPolicy Bypass -Command "Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0; Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"</CommandLine>
          <Description>Enable Remote Desktop</Description>
          <Order>$order</Order>
        </SynchronousCommand>
"@)
        $order++
    }

    if ($DisableConsumer) {
        $commands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>powershell -ExecutionPolicy Bypass -Command "New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force; New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableWindowsConsumerFeatures -Type DWord -Value 1 -Force"</CommandLine>
          <Description>Disable consumer features</Description>
          <Order>$order</Order>
        </SynchronousCommand>
"@)
        $order++
    }

    if ($InstallToolkit -and $ToolkitInstallCommand) {
        $commands.Add(@"
        <SynchronousCommand wcm:action="add">
          <CommandLine>powershell -ExecutionPolicy Bypass -Command "$(Escape-Xml $ToolkitInstallCommand)"</CommandLine>
          <Description>Install JayJaysToolkit</Description>
          <Order>$order</Order>
        </SynchronousCommand>
"@)
        $order++
    }

    $firstLogonXml = ""
    if ($commands.Count -gt 0) {
$firstLogonXml = @"
      <FirstLogonCommands>
$($commands -join "`r`n")
      </FirstLogonCommands>
"@
    }

@"
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated locally by JayJaysToolkit Unattend Builder GUI. Review before production use. -->
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>$(Escape-Xml $Locale)</UILanguage>
      </SetupUILanguage>
      <InputLocale>$(Escape-Xml $Keyboard)</InputLocale>
      <SystemLocale>$(Escape-Xml $Locale)</SystemLocale>
      <UILanguage>$(Escape-Xml $Locale)</UILanguage>
      <UserLocale>$(Escape-Xml $Locale)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ImageInstall>
        <OSImage>
          <InstallToAvailablePartition>false</InstallToAvailablePartition>
          <WillShowUI>OnError</WillShowUI>
          <InstallFrom>
            <MetaData wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
              <Key>/IMAGE/NAME</Key>
              <Value>$(Escape-Xml $Edition)</Value>
            </MetaData>
          </InstallFrom>
        </OSImage>
      </ImageInstall>
      <UserData>
        <AcceptEula>true</AcceptEula>
        <FullName>$(Escape-Xml $Owner)</FullName>
        <Organization>$(Escape-Xml $Owner)</Organization>
      </UserData>
    </component>
  </settings>

  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>$(Escape-Xml $ComputerName)</ComputerName>
      <RegisteredOwner>$(Escape-Xml $Owner)</RegisteredOwner>
      <TimeZone>$(Escape-Xml $TimeZone)</TimeZone>
    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$(Escape-Xml $Keyboard)</InputLocale>
      <SystemLocale>$(Escape-Xml $Locale)</SystemLocale>
      <UILanguage>$(Escape-Xml $Locale)</UILanguage>
      <UserLocale>$(Escape-Xml $Locale)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
$oobeXml
      </OOBE>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <Name>$(Escape-Xml $LocalAdmin)</Name>
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
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "JayJaysToolkit - Unattend Builder"
$form.Size = New-Object System.Drawing.Size(900,650)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(25,25,25)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI",10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "JayJays Unattend Builder"
$title.Font = New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(0,220,120)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20,15)
$form.Controls.Add($title)

$note = New-Object System.Windows.Forms.Label
$note.Text = "Mode: LOCAL - values are processed on this computer."
$note.ForeColor = [System.Drawing.Color]::LightGray
$note.AutoSize = $true
$note.Location = New-Object System.Drawing.Point(25,55)
$form.Controls.Add($note)

function Add-Label($text,$x,$y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x,$y)
    $l.Size = New-Object System.Drawing.Size(170,25)
    $form.Controls.Add($l)
    return $l
}

function Add-Text($x,$y,$w,$value) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x,$y)
    $t.Size = New-Object System.Drawing.Size($w,25)
    $t.Text = $value
    $t.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
    $t.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($t)
    return $t
}

function Add-Check($text,$x,$y,$checked) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $text
    $c.Location = New-Object System.Drawing.Point($x,$y)
    $c.Size = New-Object System.Drawing.Size(360,25)
    $c.Checked = $checked
    $form.Controls.Add($c)
    return $c
}

Add-Label "Computer Name" 25 100 | Out-Null
$txtComputer = Add-Text 200 100 220 "JAYJAY-PC"

Add-Label "Registered Owner" 25 135 | Out-Null
$txtOwner = Add-Text 200 135 220 "User"

Add-Label "Windows Edition" 25 170 | Out-Null
$cboEdition = New-Object System.Windows.Forms.ComboBox
$cboEdition.Location = New-Object System.Drawing.Point(200,170)
$cboEdition.Size = New-Object System.Drawing.Size(220,25)
$cboEdition.DropDownStyle = "DropDownList"
$cboEdition.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
$cboEdition.ForeColor = [System.Drawing.Color]::White
@("Windows 11 Pro","Windows 11 Home","Windows 11 Enterprise","Windows 10 Pro","Windows 10 Home","Windows 10 Enterprise") | ForEach-Object { $cboEdition.Items.Add($_) | Out-Null }
$cboEdition.SelectedIndex = 0
$form.Controls.Add($cboEdition)

Add-Label "Time Zone" 25 205 | Out-Null
$txtTimeZone = Add-Text 200 205 220 "Eastern Standard Time"

Add-Label "Locale" 25 240 | Out-Null
$txtLocale = Add-Text 200 240 220 "en-US"

Add-Label "Keyboard" 25 275 | Out-Null
$txtKeyboard = Add-Text 200 275 220 "en-US"

Add-Label "Local Admin" 465 100 | Out-Null
$txtAdmin = Add-Text 630 100 220 "JayAdmin"

Add-Label "Admin Password" 465 135 | Out-Null
$txtPass = Add-Text 630 135 220 ""
$txtPass.UseSystemPasswordChar = $true

$chkSetPassword = Add-Check "Include local admin password in XML" 465 170 $false
$chkSkipOobe = Add-Check "Skip most OOBE prompts" 465 205 $true
$chkRdp = Add-Check "Enable Remote Desktop" 465 240 $false
$chkConsumer = Add-Check "Disable consumer features/suggestions" 465 275 $true
$chkInstallToolkit = Add-Check "Install JayJaysToolkit at first logon" 465 310 $false

Add-Label "Toolkit Command" 25 325 | Out-Null
$txtToolkit = Add-Text 200 325 650 'irm https://raw.githubusercontent.com/jmjohnson5471/JayJaysToolkit/main/install.ps1 | iex'

$preview = New-Object System.Windows.Forms.TextBox
$preview.Location = New-Object System.Drawing.Point(25,370)
$preview.Size = New-Object System.Drawing.Size(825,170)
$preview.Multiline = $true
$preview.ScrollBars = "Both"
$preview.WordWrap = $false
$preview.BackColor = [System.Drawing.Color]::FromArgb(10,10,10)
$preview.ForeColor = [System.Drawing.Color]::FromArgb(0,220,120)
$preview.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($preview)

function Get-CurrentXml {
    return New-AutounattendXml `
        -ComputerName $txtComputer.Text `
        -Owner $txtOwner.Text `
        -Edition $cboEdition.SelectedItem `
        -TimeZone $txtTimeZone.Text `
        -Locale $txtLocale.Text `
        -Keyboard $txtKeyboard.Text `
        -LocalAdmin $txtAdmin.Text `
        -Password $txtPass.Text `
        -SetPassword $chkSetPassword.Checked `
        -SkipOobe $chkSkipOobe.Checked `
        -EnableRdp $chkRdp.Checked `
        -DisableConsumer $chkConsumer.Checked `
        -InstallToolkit $chkInstallToolkit.Checked `
        -ToolkitInstallCommand $txtToolkit.Text
}

$btnPreview = New-Object System.Windows.Forms.Button
$btnPreview.Text = "Preview XML"
$btnPreview.Location = New-Object System.Drawing.Point(25,555)
$btnPreview.Size = New-Object System.Drawing.Size(120,35)
$form.Controls.Add($btnPreview)

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = "Export XML"
$btnExport.Location = New-Object System.Drawing.Point(155,555)
$btnExport.Size = New-Object System.Drawing.Size(120,35)
$form.Controls.Add($btnExport)

$btnOpenTemplates = New-Object System.Windows.Forms.Button
$btnOpenTemplates.Text = "Open Templates"
$btnOpenTemplates.Location = New-Object System.Drawing.Point(285,555)
$btnOpenTemplates.Size = New-Object System.Drawing.Size(130,35)
$form.Controls.Add($btnOpenTemplates)

$btnOpenWeb = New-Object System.Windows.Forms.Button
$btnOpenWeb.Text = "Open Schneegans"
$btnOpenWeb.Location = New-Object System.Drawing.Point(425,555)
$btnOpenWeb.Size = New-Object System.Drawing.Size(140,35)
$form.Controls.Add($btnOpenWeb)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(730,555)
$btnClose.Size = New-Object System.Drawing.Size(120,35)
$form.Controls.Add($btnClose)

$btnPreview.Add_Click({
    $preview.Text = Get-CurrentXml
})

$btnExport.Add_Click({
    $save = New-Object System.Windows.Forms.SaveFileDialog
    $save.Filter = "Autounattend XML|autounattend.xml|XML files|*.xml|All files|*.*"
    $save.FileName = "autounattend.xml"
    $save.Title = "Export autounattend.xml"
    if ($save.ShowDialog() -eq "OK") {
        Get-CurrentXml | Set-Content $save.FileName -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Exported:`n$($save.FileName)","JayJaysToolkit")
        Start-Process explorer.exe "/select,`"$($save.FileName)`""
    }
})

$btnOpenTemplates.Add_Click({
    $base = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
    $templates = Join-Path $base "Templates"
    New-Item -ItemType Directory -Force -Path $templates | Out-Null
    Start-Process explorer.exe $templates
})

$btnOpenWeb.Add_Click({
    Start-Process "https://schneegans.de/windows/unattend-generator/"
})

$btnClose.Add_Click({ $form.Close() })

$preview.Text = Get-CurrentXml
[void]$form.ShowDialog()
