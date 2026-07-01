Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'Temp cleanup attempted.'
