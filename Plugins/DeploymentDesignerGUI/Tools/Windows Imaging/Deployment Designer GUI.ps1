Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Continue"

function XmlEscape {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return [System.Security.SecurityElement]::Escape($Text)
}

function Add-Label {
    param($Parent,[string]$Text,[int]$X,[int]$Y,[int]$W=180)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point($X,$Y)
    $l.Size = New-Object System.Drawing.Size($W,22)
    $l.ForeColor = [System.Drawing.Color]::LightGray
    $Parent.Controls.Add($l)
    return $l
}

function Add-TextBox {
    param($Parent,[int]$X,[int]$Y,[int]$W=220,[string]$Text="")
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($X,$Y)
    $t.Size = New-Object System.Drawing.Size($W,26)
    $t.Text = $Text
    $t.BackColor = [System.Drawing.Color]::FromArgb(35,35,35)
    $t.ForeColor = [System.Drawing.Color]::White
    $Parent.Controls.Add($t)
    return $t
}

function Add-Combo {
    param($Parent,[int]$X,[int]$Y,[int]$W,[string[]]$Items,[string]$Selected)
    $c = New-Object System.Windows.Forms.ComboBox
    $c.Location = New-Object System.Drawing.Point($X,$Y)
    $c.Size = New-Object System.Drawing.Size($W,26)
    $c.DropDownStyle = "DropDownList"
    $c.BackColor = [System.Drawing.Color]::FromArgb(35,35,35)
    $c.ForeColor = [System.Drawing.Color]::White
    [void]$c.Items.AddRange($Items)
    $c.SelectedItem = $Selected
    if ($c.SelectedIndex -lt 0) { $c.SelectedIndex = 0 }
    $Parent.Controls.Add($c)
    return $c
}

function Add-Check {
    param($Parent,[string]$Text,[int]$X,[int]$Y,[bool]$Checked=$false)
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $Text
    $cb.Location = New-Object System.Drawing.Point($X,$Y)
    $cb.Size = New-Object System.Drawing.Size(360,24)
    $cb.ForeColor = [System.Drawing.Color]::White
    $cb.Checked = $Checked
    $Parent.Controls.Add($cb)
    return $cb
}

function Build-FirstLogonCommands {
    $commands = New-Object System.Collections.Generic.List[object]

    if ($chkBypassNetwork.Checked) {
        $commands.Add([PSCustomObject]@{Order=$commands.Count+1;Description="Bypass network requirement";Command='reg add HKLM\SYSTEM\Setup\LabConfig /v BypassNRO /t REG_DWORD /d 1 /f'})
    }
    if ($chkDisableConsumer.Checked) {
        $commands.Add([PSCustomObject]@{Order=$commands.Count+1;Description="Disable consumer features";Command='reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f'})
    }
    if ($chkEnableRdp.Checked) {
        $commands.Add([PSCustomObject]@{Order=$commands.Count+1;Description="Enable Remote Desktop";Command='powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ItemProperty ''HKLM:\System\CurrentControlSet\Control\Terminal Server'' -Name fDenyTSConnections -Value 0; Enable-NetFirewallRule -DisplayGroup ''Remote Desktop''"'})
    }
    if ($chkToolkit.Checked) {
        $commands.Add([PSCustomObject]@{Order=$commands.Count+1;Description="JayJaysToolkit install reminder";Command='powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host ''Run JayJaysToolkit: irm https://raw.githubusercontent.com/jmjohnson5471/JayJaysToolkit/main/install.ps1 | iex''"'})
    }
    if ($chkCtt.Checked) {
        $commands.Add([PSCustomObject]@{Order=$commands.Count+1;Description="Chris Titus utility reminder";Command='powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host ''Optional: irm https://christitus.com/win | iex''"'})
    }
    if (-not [string]::IsNullOrWhiteSpace($txtCustom.Text)) {
        $safe = $txtCustom.Text.Replace('"','\"')
        $commands.Add([PSCustomObject]@{Order=$commands.Count+1;Description="Custom command";Command="powershell -NoProfile -ExecutionPolicy Bypass -Command `"$safe`""})
    }

    return $commands
}

function Build-FirstLogonXml {
    param($Commands)
    if ($Commands.Count -eq 0) { return "" }

    $x = "      <FirstLogonCommands>`r`n"
    foreach ($cmd in $Commands) {
        $x += "        <SynchronousCommand wcm:action=`"add`">`r`n"
        $x += "          <Order>$($cmd.Order)</Order>`r`n"
        $x += "          <Description>$(XmlEscape $cmd.Description)</Description>`r`n"
        $x += "          <CommandLine>$(XmlEscape $cmd.Command)</CommandLine>`r`n"
        $x += "        </SynchronousCommand>`r`n"
    }
    $x += "      </FirstLogonCommands>`r`n"
    return $x
}

function Build-UserXml {
    if (-not $chkCreateUser.Checked) { return "" }

    $user = if ([string]::IsNullOrWhiteSpace($txtUsername.Text)) { "Admin" } else { $txtUsername.Text }
    $passwordXml = ""
    if (-not [string]::IsNullOrWhiteSpace($txtPassword.Text)) {
        $passwordXml = @"
            <Password>
              <Value>$(XmlEscape $txtPassword.Text)</Value>
              <PlainText>true</PlainText>
            </Password>

"@
    }

@"
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>$(XmlEscape $user)</Name>
            <Group>Administrators</Group>
            <DisplayName>$(XmlEscape $user)</DisplayName>
$passwordXml          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>

"@
}

function Build-AutoLogonXml {
    if (-not $chkAutoLogon.Checked) { return "" }
    if ([string]::IsNullOrWhiteSpace($txtPassword.Text)) { return "" }
    $user = if ([string]::IsNullOrWhiteSpace($txtUsername.Text)) { "Admin" } else { $txtUsername.Text }

@"
      <AutoLogon>
        <Username>$(XmlEscape $user)</Username>
        <Enabled>true</Enabled>
        <LogonCount>1</LogonCount>
        <Password>
          <Value>$(XmlEscape $txtPassword.Text)</Value>
          <PlainText>true</PlainText>
        </Password>
      </AutoLogon>

"@
}

function Build-UnattendXml {
    $arch = $cmbArch.SelectedItem.ToString()
    $edition = $cmbEdition.SelectedItem.ToString()
    $locale = $txtLocale.Text
    $keyboard = $txtKeyboard.Text
    $timezone = $txtTimeZone.Text

    $productKeyXml = ""
    if (-not [string]::IsNullOrWhiteSpace($txtProductKey.Text)) {
        $productKeyXml = @"
        <ProductKey>
          <Key>$(XmlEscape $txtProductKey.Text)</Key>
          <WillShowUI>OnError</WillShowUI>
        </ProductKey>

"@
    }

    $computerXml = ""
    if (-not [string]::IsNullOrWhiteSpace($txtComputerName.Text)) {
        $computerXml = "      <ComputerName>$(XmlEscape $txtComputerName.Text)</ComputerName>`r`n"
    }

    $commands = Build-FirstLogonCommands
    $firstLogonXml = Build-FirstLogonXml $commands
    $userXml = Build-UserXml
    $autoLogonXml = Build-AutoLogonXml

@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="$(XmlEscape $arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>$(XmlEscape $locale)</UILanguage>
      </SetupUILanguage>
      <InputLocale>$(XmlEscape $keyboard)</InputLocale>
      <SystemLocale>$(XmlEscape $locale)</SystemLocale>
      <UILanguage>$(XmlEscape $locale)</UILanguage>
      <UserLocale>$(XmlEscape $locale)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="$(XmlEscape $arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
$productKeyXml      <ImageInstall>
        <OSImage>
          <InstallFrom>
            <MetaData wcm:action="add">
              <Key>/IMAGE/NAME</Key>
              <Value>$(XmlEscape $edition)</Value>
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
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="$(XmlEscape $arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
$computerXml      <TimeZone>$(XmlEscape $timezone)</TimeZone>
    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="$(XmlEscape $arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$(XmlEscape $keyboard)</InputLocale>
      <SystemLocale>$(XmlEscape $locale)</SystemLocale>
      <UILanguage>$(XmlEscape $locale)</UILanguage>
      <UserLocale>$(XmlEscape $locale)</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="$(XmlEscape $arch)" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>$($chkHideEula.Checked.ToString().ToLower())</HideEULAPage>
        <HideOnlineAccountScreens>$($chkHideOnline.Checked.ToString().ToLower())</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>$($chkBypassNetwork.Checked.ToString().ToLower())</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
        <SkipMachineOOBE>$($chkSkipMachine.Checked.ToString().ToLower())</SkipMachineOOBE>
        <SkipUserOOBE>$($chkSkipUser.Checked.ToString().ToLower())</SkipUserOOBE>
      </OOBE>
$userXml$autoLogonXml$firstLogonXml    </component>
  </settings>
</unattend>
"@
}

function Update-Preview {
    $txtPreview.Text = Build-UnattendXml
    $commands = Build-FirstLogonCommands
    $plan = New-Object System.Collections.Generic.List[string]
    $plan.Add("JayJaysToolkit Deployment Plan")
    $plan.Add("")
    $plan.Add("Edition: $($cmbEdition.SelectedItem)")
    $plan.Add("Architecture: $($cmbArch.SelectedItem)")
    $plan.Add("Locale: $($txtLocale.Text)")
    $plan.Add("Time Zone: $($txtTimeZone.Text)")
    $plan.Add("Computer Name: $($txtComputerName.Text)")
    $plan.Add("Local Admin: $($chkCreateUser.Checked) $($txtUsername.Text)")
    $plan.Add("")
    $plan.Add("First Logon Commands:")
    foreach ($cmd in $commands) { $plan.Add("$($cmd.Order). $($cmd.Description) - $($cmd.Command)") }
    $txtPlan.Text = ($plan -join [Environment]::NewLine)
}

function Export-Files {
    Update-Preview

    $desktop = [Environment]::GetFolderPath("Desktop")
    if (!(Test-Path $desktop)) { $desktop = $env:TEMP }
    $outDir = Join-Path $desktop "JayJaysDeployment"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $xmlPath = Join-Path $outDir "autounattend.xml"
    $profilePath = Join-Path $outDir "deployment-profile.json"
    $planPath = Join-Path $outDir "deployment-plan.txt"

    $txtPreview.Text | Set-Content $xmlPath -Encoding UTF8
    $txtPlan.Text | Set-Content $planPath -Encoding UTF8

    $profile = [ordered]@{
        Edition = $cmbEdition.SelectedItem.ToString()
        Architecture = $cmbArch.SelectedItem.ToString()
        Locale = $txtLocale.Text
        Keyboard = $txtKeyboard.Text
        TimeZone = $txtTimeZone.Text
        ComputerName = $txtComputerName.Text
        ProductKeySupplied = (-not [string]::IsNullOrWhiteSpace($txtProductKey.Text))
        HideEula = $chkHideEula.Checked
        HideOnlineAccountScreens = $chkHideOnline.Checked
        BypassNetworkRequirement = $chkBypassNetwork.Checked
        SkipMachineOOBE = $chkSkipMachine.Checked
        SkipUserOOBE = $chkSkipUser.Checked
        CreateLocalAdmin = $chkCreateUser.Checked
        LocalAdminUsername = $txtUsername.Text
        LocalAdminPasswordSupplied = (-not [string]::IsNullOrWhiteSpace($txtPassword.Text))
        AutoLogonOnce = $chkAutoLogon.Checked
        DisableConsumerFeatures = $chkDisableConsumer.Checked
        EnableRdp = $chkEnableRdp.Checked
        ToolkitReminder = $chkToolkit.Checked
        ChrisTitusReminder = $chkCtt.Checked
        CustomCommand = $txtCustom.Text
    }
    $profile | ConvertTo-Json -Depth 5 | Set-Content $profilePath -Encoding UTF8

    [System.Windows.Forms.MessageBox]::Show("Export complete:`r`n$outDir","Deployment Designer") | Out-Null
    Start-Process explorer.exe $outDir
}

# GUI
$form = New-Object System.Windows.Forms.Form
$form.Text = "JayJaysToolkit Deployment Designer"
$form.Size = New-Object System.Drawing.Size(1240,780)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(18,20,22)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI",9)

$title = New-Object System.Windows.Forms.Label
$title.Text = "JayJaysToolkit Deployment Designer"
$title.Font = New-Object System.Drawing.Font("Segoe UI",18,[System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(0,220,120)
$title.Location = New-Object System.Drawing.Point(18,12)
$title.Size = New-Object System.Drawing.Size(500,34)
$form.Controls.Add($title)

$left = New-Object System.Windows.Forms.Panel
$left.Location = New-Object System.Drawing.Point(18,55)
$left.Size = New-Object System.Drawing.Size(430,635)
$left.BackColor = [System.Drawing.Color]::FromArgb(27,31,36)
$form.Controls.Add($left)

Add-Label $left "Edition" 15 15
$cmbEdition = Add-Combo $left 15 38 190 @("Windows 11 Pro","Windows 11 Home","Windows 10 Pro","Windows 10 Home") "Windows 11 Pro"
Add-Label $left "Architecture" 225 15
$cmbArch = Add-Combo $left 225 38 120 @("amd64","x86") "amd64"

Add-Label $left "Locale" 15 75
$txtLocale = Add-TextBox $left 15 98 120 "en-US"
Add-Label $left "Keyboard" 150 75
$txtKeyboard = Add-TextBox $left 150 98 170 "0409:00000409"

Add-Label $left "Time Zone" 15 135
$txtTimeZone = Add-TextBox $left 15 158 250 "Eastern Standard Time"
Add-Label $left "Computer Name" 15 195
$txtComputerName = Add-TextBox $left 15 218 250 ""

Add-Label $left "Product Key" 15 255
$txtProductKey = Add-TextBox $left 15 278 250 ""

$chkHideEula = Add-Check $left "Accept / hide EULA" 15 320 $true
$chkHideOnline = Add-Check $left "Hide online account screens" 15 345 $true
$chkBypassNetwork = Add-Check $left "Bypass network requirement" 15 370 $true
$chkSkipMachine = Add-Check $left "Skip machine OOBE" 15 395 $true
$chkSkipUser = Add-Check $left "Skip user OOBE" 15 420 $false

$chkCreateUser = Add-Check $left "Create local admin account" 15 455 $true
Add-Label $left "Username" 15 480
$txtUsername = Add-TextBox $left 15 503 150 "Admin"
Add-Label $left "Password" 180 480
$txtPassword = Add-TextBox $left 180 503 170 ""
$txtPassword.UseSystemPasswordChar = $true
$chkAutoLogon = Add-Check $left "Auto-logon once" 15 535 $false

$chkDisableConsumer = Add-Check $left "Disable consumer features" 15 565 $true
$chkEnableRdp = Add-Check $left "Enable Remote Desktop" 15 590 $true

$middle = New-Object System.Windows.Forms.Panel
$middle.Location = New-Object System.Drawing.Point(18,695)
$middle.Size = New-Object System.Drawing.Size(1190,40)
$middle.BackColor = [System.Drawing.Color]::FromArgb(18,20,22)
$form.Controls.Add($middle)

$chkToolkit = Add-Check $form "Add JayJaysToolkit reminder" 470 58 $false
$chkCtt = Add-Check $form "Add Chris Titus utility reminder" 470 83 $false
Add-Label $form "Custom First Logon PowerShell Command" 470 113 300
$txtCustom = New-Object System.Windows.Forms.TextBox
$txtCustom.Location = New-Object System.Drawing.Point(470,136)
$txtCustom.Size = New-Object System.Drawing.Size(730,55)
$txtCustom.Multiline = $true
$txtCustom.BackColor = [System.Drawing.Color]::FromArgb(35,35,35)
$txtCustom.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($txtCustom)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(470,205)
$tabs.Size = New-Object System.Drawing.Size(738,485)
$form.Controls.Add($tabs)

$tabXml = New-Object System.Windows.Forms.TabPage
$tabXml.Text = "XML Preview"
$tabXml.BackColor = [System.Drawing.Color]::FromArgb(10,10,10)
$tabs.TabPages.Add($tabXml)

$tabPlan = New-Object System.Windows.Forms.TabPage
$tabPlan.Text = "Deployment Plan"
$tabPlan.BackColor = [System.Drawing.Color]::FromArgb(10,10,10)
$tabs.TabPages.Add($tabPlan)

$txtPreview = New-Object System.Windows.Forms.TextBox
$txtPreview.Multiline = $true
$txtPreview.ScrollBars = "Both"
$txtPreview.WordWrap = $false
$txtPreview.Dock = "Fill"
$txtPreview.Font = New-Object System.Drawing.Font("Consolas",9)
$txtPreview.BackColor = [System.Drawing.Color]::FromArgb(5,6,8)
$txtPreview.ForeColor = [System.Drawing.Color]::FromArgb(199,247,221)
$tabXml.Controls.Add($txtPreview)

$txtPlan = New-Object System.Windows.Forms.TextBox
$txtPlan.Multiline = $true
$txtPlan.ScrollBars = "Both"
$txtPlan.WordWrap = $false
$txtPlan.Dock = "Fill"
$txtPlan.Font = New-Object System.Drawing.Font("Consolas",9)
$txtPlan.BackColor = [System.Drawing.Color]::FromArgb(5,6,8)
$txtPlan.ForeColor = [System.Drawing.Color]::White
$tabPlan.Controls.Add($txtPlan)

$btnGenerate = New-Object System.Windows.Forms.Button
$btnGenerate.Text = "Generate Preview"
$btnGenerate.Location = New-Object System.Drawing.Point(470,700)
$btnGenerate.Size = New-Object System.Drawing.Size(130,32)
$form.Controls.Add($btnGenerate)

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = "Export Files"
$btnExport.Location = New-Object System.Drawing.Point(610,700)
$btnExport.Size = New-Object System.Drawing.Size(110,32)
$form.Controls.Add($btnExport)

$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy XML"
$btnCopy.Location = New-Object System.Drawing.Point(730,700)
$btnCopy.Size = New-Object System.Drawing.Size(100,32)
$form.Controls.Add($btnCopy)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(840,700)
$btnClose.Size = New-Object System.Drawing.Size(90,32)
$form.Controls.Add($btnClose)

$btnGenerate.Add_Click({ Update-Preview })
$btnExport.Add_Click({ Export-Files })
$btnCopy.Add_Click({ Update-Preview; [System.Windows.Forms.Clipboard]::SetText($txtPreview.Text); [System.Windows.Forms.MessageBox]::Show("XML copied.","Deployment Designer") | Out-Null })
$btnClose.Add_Click({ $form.Close() })

foreach ($ctrl in @($cmbEdition,$cmbArch,$txtLocale,$txtKeyboard,$txtTimeZone,$txtComputerName,$txtProductKey,$chkHideEula,$chkHideOnline,$chkBypassNetwork,$chkSkipMachine,$chkSkipUser,$chkCreateUser,$txtUsername,$txtPassword,$chkAutoLogon,$chkDisableConsumer,$chkEnableRdp,$chkToolkit,$chkCtt,$txtCustom)) {
    if ($ctrl -is [System.Windows.Forms.TextBox]) { $ctrl.Add_TextChanged({ Update-Preview }) }
    elseif ($ctrl -is [System.Windows.Forms.CheckBox]) { $ctrl.Add_CheckedChanged({ Update-Preview }) }
    elseif ($ctrl -is [System.Windows.Forms.ComboBox]) { $ctrl.Add_SelectedIndexChanged({ Update-Preview }) }
}

Update-Preview
[void]$form.ShowDialog()
