Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $BaseDir "Core\GUI.ps1")
