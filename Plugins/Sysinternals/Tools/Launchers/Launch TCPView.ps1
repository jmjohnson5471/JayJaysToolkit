$BaseDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$Exe = Join-Path $BaseDir "PortableApps\Sysinternals\tcpview64.exe"
if (Test-Path $Exe) {
    Start-Process $Exe -Verb RunAs
} else {
    Write-Host "tcpview64.exe not found."
    Write-Host "Run 'Download Sysinternals Suite' first."
    Read-Host "Press Enter to close"
}
