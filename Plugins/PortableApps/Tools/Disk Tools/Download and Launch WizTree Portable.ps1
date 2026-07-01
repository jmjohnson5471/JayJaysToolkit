$ErrorActionPreference = "Stop"

$BaseDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$PortableRoot = Join-Path $BaseDir "PortableApps\WizTree"
$ZipPath = Join-Path $env:TEMP "WizTree_Portable.zip"
$Url = "https://diskanalyzer.com/files/wiztree_4_25_portable.zip"

New-Item -ItemType Directory -Force -Path $PortableRoot | Out-Null

Write-Host "JayJaysToolkit - WizTree Portable"
Write-Host "Install folder: $PortableRoot"
Write-Host ""

try {
    Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing
    Expand-Archive -Path $ZipPath -DestinationPath $PortableRoot -Force
    Write-Host "WizTree portable is ready." -ForegroundColor Green

    $exe = Get-ChildItem $PortableRoot -Filter "WizTree*.exe" -Recurse | Select-Object -First 1
    if ($exe) {
        Start-Process $exe.FullName -Verb RunAs
    } else {
        Start-Process explorer.exe $PortableRoot
    }
}
catch {
    Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "Press Enter to close"
