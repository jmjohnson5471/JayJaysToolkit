$url="https://diskanalyzer.com/files/wiztree_4_25_portable.zip";$dest="$env:USERPROFILE\Desktop\WizTree_Portable.zip";Invoke-WebRequest $url -OutFile $dest;Write-Host "Downloaded to $dest"
