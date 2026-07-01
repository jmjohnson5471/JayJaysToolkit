$BaseDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$PortableRoot = Join-Path $BaseDir "PortableApps"
New-Item -ItemType Directory -Force -Path $PortableRoot | Out-Null

Write-Host "JayJaysToolkit Portable Apps Folder"
Write-Host $PortableRoot
Write-Host ""

Get-ChildItem $PortableRoot -Directory | ForEach-Object {
    $count = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    [PSCustomObject]@{
        AppFolder = $_.Name
        Files = $count
        Path = $_.FullName
    }
} | Format-Table -AutoSize

Start-Process explorer.exe $PortableRoot
Read-Host "Press Enter to close"
