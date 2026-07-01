Get-Service | Where-Object {$_.Name -match "ninja|ninjarmm" -or $_.DisplayName -match "Ninja"} | Format-Table Name,DisplayName,Status,StartType -AutoSize
