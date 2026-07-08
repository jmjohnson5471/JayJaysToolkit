param([Parameter(Mandatory=$true)][string]$AppId)
. (Join-Path $PSScriptRoot "ManagedAppInstaller.ps1")
Show-MAIAppMenu -AppId $AppId
Read-Host "Press Enter to close"
