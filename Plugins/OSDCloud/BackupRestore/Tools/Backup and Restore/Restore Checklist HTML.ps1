$out="$env:USERPROFILE\Desktop\RestoreChecklist_$env:COMPUTERNAME.html"
$tasks="Computer renamed","Domain/Entra joined","Windows activated","Drivers installed","BitLocker enabled","User data restored","Office/Outlook/OneDrive/Teams tested","Printers installed","RMM/AV healthy","User accepted"
$rows=$tasks|%{"<tr><td>☐</td><td>$_</td><td></td></tr>"}
$html="<html><body style='font-family:Segoe UI'><h1>JayJaysToolkit Restore Checklist</h1><table border='1' cellpadding='8'><tr><th>Done</th><th>Task</th><th>Notes</th></tr>$($rows -join '')</table></body></html>"
$html|Set-Content $out;Start-Process $out;Write-Host "Saved to $out"
