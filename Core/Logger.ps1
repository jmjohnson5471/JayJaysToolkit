# Logger.ps1
# Writes leveled, timestamped log entries and trims old log files automatically.

$Script:JJT_LogRetentionDays = 30

function Write-JJTLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("Info", "Warn", "Error")][string]$Level = "Info"
    )

    try {
        $logDir = Join-Path $Script:BaseDir "Logs"
        New-Item -ItemType Directory -Force -Path $logDir -ErrorAction Stop | Out-Null

        $file = Join-Path $logDir ("JayJaysToolkit_" + (Get-Date -Format "yyyyMMdd") + ".log")
        $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpper(), $Message
        Add-Content -Path $file -Value $line -ErrorAction Stop
    } catch {
        # Logging must never crash the app. Fall back to console only.
        Write-Host "LOG FAILED: $Message" -ForegroundColor DarkYellow
    }
}

function Invoke-JJTLogCleanup {
    # Deletes log files older than the retention window so Logs\ doesn't grow forever
    # on a technician's laptop that runs this daily.
    try {
        $logDir = Join-Path $Script:BaseDir "Logs"
        if (-not (Test-Path $logDir)) { return }

        $cutoff = (Get-Date).AddDays(-$Script:JJT_LogRetentionDays)
        Get-ChildItem -Path $logDir -Filter "JayJaysToolkit_*.log" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    } catch {
        # Non-fatal; cleanup is best-effort.
    }
}
