$client=Read-Host "Client/User name"
if(!$client){$client=$env:USERNAME}
$out=Join-Path $env:USERPROFILE ("Desktop\RestoreChecklist_{0}_{1}.html" -f $client.Replace(" ","_"),(Get-Date -Format yyyyMMdd_HHmmss))
$tasks = @(
"Computer renamed correctly",
"Joined to domain or Entra ID",
"Windows activated",
"Windows fully updated",
"Drivers installed and Device Manager clean",
"BitLocker enabled and recovery key escrowed",
"User folders restored",
"Browser bookmarks/profile restored",
"Office installed and activated",
"Outlook profile configured and syncing",
"OneDrive signed in and syncing",
"Teams signed in and tested",
"Line-of-business apps installed",
"Printers installed and tested",
"RMM agent installed and checking in",
"EDR/AV installed and healthy",
"Remote support tool installed/tested",
"VPN configured and tested if needed",
"User login tested",
"Final reboot completed",
"User acceptance confirmed"
)
$rows = $tasks | ForEach-Object { "<tr><td>☐</td><td>$_</td><td></td></tr>" }
$html = @"
<html><head><title>Restore Checklist</title>
<style>
body{font-family:Segoe UI,Arial;margin:30px} h1{color:#0a7}
table{border-collapse:collapse;width:100%} td,th{border:1px solid #ccc;padding:10px}
th{background:#eee}
</style></head><body>
<h1>JayJaysToolkit New Computer Restore Checklist</h1>
<p><b>User:</b> $client<br><b>Computer:</b> $env:COMPUTERNAME<br><b>Date:</b> $(Get-Date)</p>
<table><tr><th>Done</th><th>Task</th><th>Notes</th></tr>$($rows -join "`n")</table>
</body></html>
"@
$html | Set-Content $out -Encoding UTF8
Start-Process $out
Write-Host "Saved to $out"
