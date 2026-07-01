@echo off
title JayJaysToolkit - Quick System Reference
color 0A
echo ========================================
echo   JayJaysToolkit - Quick System Reference
echo ========================================
echo.
echo Computer Name : %COMPUTERNAME%
echo User          : %USERDOMAIN%\%USERNAME%

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$cv=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; ^
$cs=Get-CimInstance Win32_ComputerSystem; ^
$bios=Get-CimInstance Win32_BIOS; ^
$cpu=Get-CimInstance Win32_Processor | Select-Object -First 1; ^
$disk=Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\"; ^
$key=(Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey; ^
if([string]::IsNullOrWhiteSpace($key)){$key='Not detected'}; ^
$lic=Get-CimInstance SoftwareLicensingProduct | Where-Object {$_.PartialProductKey -and $_.LicenseStatus -eq 1} | Select-Object -First 1; ^
$act=if($lic){'Activated'}else{'Not activated / unknown'}; ^
Write-Host ('OS            : ' + $cv.ProductName); ^
Write-Host ('Version       : ' + $(if($cv.DisplayVersion){$cv.DisplayVersion}else{$cv.ReleaseId})); ^
Write-Host ('Build         : ' + $cv.CurrentBuild); ^
Write-Host ('Manufacturer  : ' + $cs.Manufacturer); ^
Write-Host ('Model         : ' + $cs.Model); ^
Write-Host ('Serial        : ' + $bios.SerialNumber); ^
Write-Host ('CPU           : ' + $cpu.Name); ^
Write-Host ('RAM           : ' + [math]::Round($cs.TotalPhysicalMemory/1GB,1) + ' GB'); ^
Write-Host ('C: Size       : ' + [math]::Round($disk.Size/1GB,1) + ' GB'); ^
Write-Host ('C: Free       : ' + [math]::Round($disk.FreeSpace/1GB,1) + ' GB'); ^
Write-Host ('Product Key   : ' + $key); ^
Write-Host ('Activation    : ' + $act);"

echo.
echo IPv4 / Gateway:
ipconfig | findstr /i "IPv4 Default Gateway"
echo.
echo BitLocker:
manage-bde -status C: | findstr /i "Protection Conversion Percentage"
echo.
pause
