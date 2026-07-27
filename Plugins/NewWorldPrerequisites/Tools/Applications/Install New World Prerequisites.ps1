$InstallerFolder=Join-Path $PSScriptRoot "..\..\Installers"
$InstallerFolder=(Resolve-Path $InstallerFolder).Path
$MSIs=Get-ChildItem $InstallerFolder -Filter *.msi|Sort Name
if(!$MSIs){[System.Windows.Forms.MessageBox]::Show("No MSI files found in $InstallerFolder");exit}
foreach($m in $MSIs){
 Write-Host "Installing $($m.Name)..."
 Start-Process msiexec.exe -ArgumentList "/i `"$($m.FullName)`" /qn /norestart" -Wait
}
Write-Host "Done"
Pause
