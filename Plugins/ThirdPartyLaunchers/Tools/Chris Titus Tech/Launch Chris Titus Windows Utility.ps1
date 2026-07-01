Clear-Host
Write-Host "Chris Titus Tech Windows Utility" -ForegroundColor Green
Write-Host ""
Write-Host "This runs:"
Write-Host "irm https://christitus.com/win | iex"
Write-Host ""
Write-Host "This is a third-party script. Review the source and use at your own risk."
Write-Host ""
$confirm = Read-Host "Run it now? Type YES to continue"
if ($confirm -eq "YES") {
    irm https://christitus.com/win | iex
} else {
    Write-Host "Cancelled."
}
Read-Host "Press Enter to close"
