$ErrorActionPreference = "Stop"
$GitHubUser = "jmjohnson5471"
$RepoName   = "JayJaysToolkit"
$Branch     = "main"

$RepoZipUrl  = "https://github.com/$GitHubUser/$RepoName/archive/refs/heads/$Branch.zip"
$InstallPath = "$env:ProgramData\JayJaysToolkit"
$WorkPath    = Join-Path $env:TEMP "JayJaysToolkit_Install"
$ZipPath     = Join-Path $env:TEMP "JayJaysToolkit.zip"

Write-Host "Installing JayJaysToolkit from $RepoZipUrl" -ForegroundColor Green
Remove-Item $WorkPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $WorkPath | Out-Null

Invoke-WebRequest -Uri $RepoZipUrl -OutFile $ZipPath -UseBasicParsing
Expand-Archive -Path $ZipPath -DestinationPath $WorkPath -Force
$ExtractedRoot = Get-ChildItem $WorkPath -Directory | Select-Object -First 1
if (-not $ExtractedRoot) { throw "Could not find extracted repo folder." }

Remove-Item $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
Copy-Item "$($ExtractedRoot.FullName)\*" $InstallPath -Recurse -Force

$ShortcutPath = Join-Path $env:PUBLIC "Desktop\JayJaysToolkit.lnk"
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$InstallPath\Start.ps1`""
    $Shortcut.WorkingDirectory = $InstallPath
    $Shortcut.IconLocation = "powershell.exe,0"
    $Shortcut.Save()
} catch {}

Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$InstallPath\Start.ps1`""
