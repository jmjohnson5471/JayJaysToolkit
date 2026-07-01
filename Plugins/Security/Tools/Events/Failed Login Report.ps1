Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625;StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue | Select -First 100 TimeCreated,Id,ProviderName,Message | Format-List
