Get-Service rustdesk -ErrorAction SilentlyContinue | Restart-Service -Force
Write-Host 'RustDesk service restart attempted.'
