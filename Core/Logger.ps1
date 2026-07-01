function Write-JJTLog {
    param([string]$Message)
    $logDir = Join-Path $Script:BaseDir "Logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $file = Join-Path $logDir ("JayJaysToolkit_" + (Get-Date -Format "yyyyMMdd") + ".log")
    Add-Content -Path $file -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
}
