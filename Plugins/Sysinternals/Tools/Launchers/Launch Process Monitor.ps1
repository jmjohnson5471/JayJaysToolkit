$BaseDir = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
$Exe = Join-Path $BaseDir "PortableApps\Sysinternals\procmon64.exe"
if (Test-Path $Exe) {
    Start-Process $Exe -Verb RunAs
} else {
    Write-Host "procmon64.exe not found."
    Write-Host "Run 'Download Sysinternals Suite' first."
    Read-Host "Press Enter to close"
}
