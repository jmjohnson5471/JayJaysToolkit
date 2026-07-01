$url="https://download.sysinternals.com/files/SysinternalsSuite.zip"
$dest=Join-Path $env:USERPROFILE "Desktop\SysinternalsSuite.zip"
Invoke-WebRequest $url -OutFile $dest
Write-Host "Downloaded to $dest"
