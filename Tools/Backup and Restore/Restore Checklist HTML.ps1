$out="$env:USERPROFILE\Desktop\RestoreChecklist_$env:COMPUTERNAME.html"
$html="<html><body style='font-family:Segoe UI'><h1>New Computer Restore Checklist</h1><ul><li>Windows activated</li><li>Drivers installed</li><li>BitLocker enabled</li><li>User data restored</li><li>Office/Outlook/OneDrive/Teams tested</li><li>Printers installed</li><li>RMM/AV healthy</li><li>User acceptance confirmed</li></ul></body></html>"
$html|Set-Content $out
Start-Process $out
Write-Host "Saved to $out"
