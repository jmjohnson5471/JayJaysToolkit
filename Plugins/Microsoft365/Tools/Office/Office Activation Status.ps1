$p="$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs";if(Test-Path $p){cscript //nologo $p /dstatus}else{Write-Host "ospp.vbs not found."}
