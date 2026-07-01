$ErrorActionPreference = "Continue"

$ToolPath = $MyInvocation.MyCommand.Path
$BaseDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ToolPath)))
$LogsDir = Join-Path $BaseDir "Logs"

Clear-Host
Write-Host "JayJaysToolkit Tool History" -ForegroundColor Green
Write-Host ""

if (!(Test-Path $LogsDir)) {
    Write-Host "No Logs folder found."
    Read-Host "Press Enter to close"
    exit
}

$logs = Get-ChildItem $LogsDir -Filter "*.log" | Sort-Object LastWriteTime -Descending
if (!$logs) {
    Write-Host "No logs found."
    Read-Host "Press Enter to close"
    exit
}

$entries = foreach ($log in $logs | Select-Object -First 10) {
    Get-Content $log.FullName | Where-Object { $_ -match "RUN:" } | Select-Object -Last 20
}

if ($entries) {
    $entries | Select-Object -Last 50
} else {
    Write-Host "No RUN entries found in logs."
}

Write-Host ""
Read-Host "Press Enter to close"
