function Get-MAIPluginRoot {
    $current = $PSScriptRoot
    while ($current -and !(Test-Path (Join-Path $current "plugin.json"))) {
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }
    return $current
}

function Get-JJTIPBaseDir {
    $current = Get-MAIPluginRoot
    while ($current) {
        if ((Test-Path (Join-Path $current "Plugins")) -and (Test-Path (Join-Path $current "Core"))) {
            return $current
        }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }
    return "$env:ProgramData\JAYJAYsITPlatform"
}

function Get-MAIApps {
    $file = Join-Path (Get-MAIPluginRoot) "Config\apps.json"
    if (!(Test-Path $file)) { throw "Missing app manifest: $file" }
    Get-Content $file -Raw | ConvertFrom-Json
}

function Get-MAIApp {
    param([string]$AppId)
    $apps = Get-MAIApps
    if ($apps.PSObject.Properties.Name -notcontains $AppId) { throw "Unknown app: $AppId" }
    $apps.$AppId
}

function Get-MAIPaths {
    param([string]$AppId)
    $base = Get-JJTIPBaseDir
    $downloadRoot = Join-Path $base "Downloads\ManagedApps"
    $portableRoot = Join-Path $base "PortableApps"
    $appPortableRoot = Join-Path $portableRoot $AppId
    New-Item -ItemType Directory -Force -Path $downloadRoot,$portableRoot,$appPortableRoot | Out-Null
    [pscustomobject]@{
        BaseDir = $base
        DownloadRoot = $downloadRoot
        PortableRoot = $portableRoot
        AppPortableRoot = $appPortableRoot
    }
}

function Get-FileFromWeb {
    param([string]$URL,[string]$File,[string]$Label="Downloading")
    $reader = $null
    $writer = $null
    try {
        $request = [System.Net.HttpWebRequest]::Create($URL)
        $request.UserAgent = "JAYJAYs IT Platform"
        $response = $request.GetResponse()
        $dir = [IO.Path]::GetDirectoryName($File)
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        [long]$size = $response.ContentLength
        [byte[]]$buffer = New-Object byte[] 1048576
        [long]$total = 0
        $reader = $response.GetResponseStream()
        $writer = New-Object IO.FileStream $File, 'Create'
        do {
            $count = $reader.Read($buffer, 0, $buffer.Length)
            if ($count -gt 0) {
                $writer.Write($buffer, 0, $count)
                $total += $count
                if ($size -gt 0) {
                    $pct = [math]::Round(($total / $size) * 100, 2)
                    Write-Host -NoNewLine "`r$Label $pct% "
                }
            }
        } while ($count -gt 0)
        Write-Host ""
    }
    finally {
        if ($reader) { $reader.Close() }
        if ($writer) { $writer.Close() }
    }
}

function Invoke-MAIDownload {
    param([string]$AppId)
    $app = Get-MAIApp $AppId
    $paths = Get-MAIPaths $AppId
    $file = Join-Path $paths.DownloadRoot $app.FileName
    Write-Host "Downloading $($app.Name)..." -ForegroundColor Cyan
    Write-Host $app.DownloadUrl
    Get-FileFromWeb -URL $app.DownloadUrl -File $file -Label " Downloading $($app.Name)"
    Write-Host "Downloaded to: $file" -ForegroundColor Green
    return $file
}

function Find-MAIExecutable {
    param($App,$Paths)
    if ($App.PortableExe) {
        $candidate = Join-Path $Paths.PortableRoot $App.PortableExe
        if (Test-Path $candidate) { return $candidate }
    }
    if ($App.PortableExePattern) {
        $found = Get-ChildItem $Paths.AppPortableRoot -Recurse -File -Filter $App.PortableExePattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Invoke-MAIPortable {
    param([string]$AppId)
    $app = Get-MAIApp $AppId
    $paths = Get-MAIPaths $AppId
    $download = Invoke-MAIDownload $AppId
    switch ($app.Type) {
        "Zip" { Expand-Archive -Path $download -DestinationPath $paths.AppPortableRoot -Force }
        "ExePortable" { Copy-Item $download (Join-Path $paths.AppPortableRoot $app.FileName) -Force }
        "Installer" {
            if (!$app.PortableArgs) { throw "No PortableArgs defined for $($app.Name)" }
            Start-Process -FilePath $download -ArgumentList $app.PortableArgs -Wait
        }
    }
    $exe = Find-MAIExecutable $app $paths
    if ($exe) {
        Write-Host "Launching: $exe" -ForegroundColor Green
        if ($app.RunAsAdmin) { Start-Process $exe -Verb RunAs } else { Start-Process $exe }
    } else {
        Write-Host "Executable not detected. Opening portable folder." -ForegroundColor Yellow
        Start-Process explorer.exe $paths.AppPortableRoot
    }
}

function Invoke-MAIInstall {
    param([string]$AppId)
    $app = Get-MAIApp $AppId
    if (!$app.SupportsNormalInstall) {
        Write-Host "Normal install is not available for $($app.Name)." -ForegroundColor Yellow
        return
    }
    $download = Invoke-MAIDownload $AppId
    Start-Process -FilePath $download -ArgumentList $app.InstallArgs -Wait
    Write-Host "Install completed." -ForegroundColor Green
    if ($app.InstalledExe) {
        $exe = [Environment]::ExpandEnvironmentVariables($app.InstalledExe)
        if (Test-Path $exe) { Start-Process $exe }
    }
}

function Invoke-MAILaunch {
    param([string]$AppId)
    $app = Get-MAIApp $AppId
    $paths = Get-MAIPaths $AppId
    $exe = Find-MAIExecutable $app $paths
    if ($exe) {
        if ($app.RunAsAdmin) { Start-Process $exe -Verb RunAs } else { Start-Process $exe }
    } else {
        Write-Host "$($app.Name) was not found. Download portable first." -ForegroundColor Yellow
        Start-Process explorer.exe $paths.AppPortableRoot
    }
}

function Show-MAIAppMenu {
    param([string]$AppId)
    $app = Get-MAIApp $AppId
    $paths = Get-MAIPaths $AppId
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " JAYJAYs IT Platform - Managed App Installer" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "App: $($app.Name)" -ForegroundColor Green
    Write-Host $app.Description
    Write-Host ""
    Write-Host "Portable folder: $($paths.AppPortableRoot)"
    Write-Host ""
    if ($app.SupportsNormalInstall) { Write-Host "  [1] Normal Installation" }
    if ($app.SupportsPortable) { Write-Host "  [2] Download/Update Portable" }
    Write-Host "  [3] Launch Existing Portable"
    Write-Host "  [4] Open Portable Folder"
    Write-Host "  [5] Open Downloads Folder"
    Write-Host "  [Q] Quit"
    Write-Host ""
    $choice = Read-Host "Choose"
    switch ($choice.ToUpper()) {
        "1" { Invoke-MAIInstall $AppId }
        "2" { Invoke-MAIPortable $AppId }
        "3" { Invoke-MAILaunch $AppId }
        "4" { Start-Process explorer.exe $paths.AppPortableRoot }
        "5" { Start-Process explorer.exe $paths.DownloadRoot }
    }
}
