Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$pluginRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
. (Join-Path $pluginRoot "Engine\SoftwareRepositoryManager.ps1")
$form = New-Object System.Windows.Forms.Form
$form.Text = "JAYJAYs IT Platform - Software Repository Manager"
$form.Size = New-Object System.Drawing.Size(760,390)
$form.StartPosition = "CenterScreen"
$label = New-Object System.Windows.Forms.Label
$label.Text = "Pick a USB/local/network software repository. Blank = auto-detect flash drives/configured paths, then winget fallback."
$label.Location = New-Object System.Drawing.Point(20,20)
$label.Size = New-Object System.Drawing.Size(700,50)
$form.Controls.Add($label)
$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(20,85)
$txtPath.Size = New-Object System.Drawing.Size(590,28)
$form.Controls.Add($txtPath)
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse"
$btnBrowse.Location = New-Object System.Drawing.Point(620,84)
$btnBrowse.Size = New-Object System.Drawing.Size(100,30)
$form.Controls.Add($btnBrowse)
$cboProfile = New-Object System.Windows.Forms.ComboBox
$cboProfile.Location = New-Object System.Drawing.Point(20,135)
$cboProfile.Size = New-Object System.Drawing.Size(300,28)
$cboProfile.DropDownStyle = "DropDownList"
Get-SRMProfiles | % { $cboProfile.Items.Add($_.Name) | Out-Null }
if ($cboProfile.Items.Count -gt 0) { $cboProfile.SelectedIndex = 0 }
$form.Controls.Add($cboProfile)
$chkSave = New-Object System.Windows.Forms.CheckBox
$chkSave.Text = "Save selected path as default NetworkPath"
$chkSave.Location = New-Object System.Drawing.Point(20,175)
$chkSave.Size = New-Object System.Drawing.Size(320,25)
$form.Controls.Add($chkSave)
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Start Install"
$btnInstall.Location = New-Object System.Drawing.Point(20,230)
$btnInstall.Size = New-Object System.Drawing.Size(140,40)
$form.Controls.Add($btnInstall)
$btnConfig = New-Object System.Windows.Forms.Button
$btnConfig.Text = "Open Config"
$btnConfig.Location = New-Object System.Drawing.Point(180,230)
$btnConfig.Size = New-Object System.Drawing.Size(140,40)
$form.Controls.Add($btnConfig)
$btnBrowse.Add_Click({ $p = Select-SRMRepositoryPath; if ($p) { $txtPath.Text = $p } })
$btnConfig.Add_Click({ Start-Process explorer.exe (Join-Path $pluginRoot "Config") })
$btnInstall.Add_Click({
    $profile = $cboProfile.SelectedItem
    $path = $txtPath.Text
    if ($chkSave.Checked -and $path -and (Test-Path $path)) {
        $s = Get-SRMSettings
        $s.NetworkPath = $path
        Save-SRMSettings $s
    }
    $cmd = "-NoProfile -ExecutionPolicy Bypass -NoExit -Command `"& { . '$pluginRoot\Engine\SoftwareRepositoryManager.ps1'; Invoke-SRMProfileInstall -ProfileName '$profile' -SelectedRepositoryPath '$path' }`""
    Start-Process powershell.exe -Verb RunAs -ArgumentList $cmd
})
[void]$form.ShowDialog()
