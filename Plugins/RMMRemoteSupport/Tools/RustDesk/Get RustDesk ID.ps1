$exe="$env:ProgramFiles\RustDesk\RustDesk.exe";if(Test-Path $exe){& $exe --get-id}else{Write-Host "RustDesk.exe not found."}
