. (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))) "Engine\ManagedAppInstaller.ps1")
$apps = Get-MAIApps
Clear-Host
Write-Host "JAYJAYs IT Platform - Managed Apps" -ForegroundColor Green
Write-Host ""
foreach ($name in $apps.PSObject.Properties.Name) {
    $a = $apps.$name
    [PSCustomObject]@{
        Id = $name
        Name = $a.Name
        Type = $a.Type
        NormalInstall = $a.SupportsNormalInstall
        Portable = $a.SupportsPortable
        Description = $a.Description
    }
}
$paths = Get-MAIPaths "Sysinternals"
Write-Host ""
Write-Host "PortableApps folder: $($paths.PortableRoot)"
Start-Process explorer.exe $paths.PortableRoot
Read-Host "Press Enter to close"
