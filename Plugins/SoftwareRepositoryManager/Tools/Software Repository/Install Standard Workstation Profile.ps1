$pluginRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
. (Join-Path $pluginRoot "Engine\SoftwareRepositoryManager.ps1")
$selected = Select-SRMRepositoryPath
Invoke-SRMProfileInstall -ProfileName "Standard Workstation" -SelectedRepositoryPath $selected
Read-Host "Press Enter to close"
