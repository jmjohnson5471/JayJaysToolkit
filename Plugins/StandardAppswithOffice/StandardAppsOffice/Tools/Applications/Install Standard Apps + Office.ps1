# Replace this file with your working installer or paste it here.
$script=Join-Path $PSScriptRoot 'Install-StandardApps-With-Office-Fixed.ps1'
if(Test-Path $script){
 & $script
}else{
 Write-Host 'Place Install-StandardApps-With-Office-Fixed.ps1 in this folder and keep this filename.'
 Read-Host
}
