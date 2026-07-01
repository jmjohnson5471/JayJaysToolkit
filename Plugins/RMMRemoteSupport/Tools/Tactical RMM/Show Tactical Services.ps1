Get-Service | Where-Object {$_.Name -match "tactical|mesh|agent" -or $_.DisplayName -match "Tactical|Mesh|Agent"} | Format-Table Name,DisplayName,Status,StartType -AutoSize
