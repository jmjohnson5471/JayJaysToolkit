net stop wuauserv
net stop bits
Remove-Item "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
net start bits
net start wuauserv
