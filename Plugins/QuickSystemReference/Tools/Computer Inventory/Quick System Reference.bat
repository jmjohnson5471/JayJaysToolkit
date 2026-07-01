@echo off
title JayJaysToolkit - Quick System Reference
color 0A
echo ========================================
echo   JayJaysToolkit - Quick System Reference
echo ========================================
echo.
echo Computer Name : %COMPUTERNAME%
echo User          : %USERDOMAIN%\%USERNAME%
for /f "tokens=3*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName ^| find "ProductName"') do echo OS            : %%A %%B
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DisplayVersion ^| find "DisplayVersion"') do echo Version       : %%A
for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild ^| find "CurrentBuild"') do echo Build         : %%A
for /f "tokens=2 delims==" %%A in ('wmic computersystem get manufacturer /value ^| find "="') do echo Manufacturer  : %%A
for /f "tokens=2 delims==" %%A in ('wmic computersystem get model /value ^| find "="') do echo Model         : %%A
for /f "tokens=2 delims==" %%A in ('wmic bios get serialnumber /value ^| find "="') do echo Serial        : %%A
for /f "tokens=2 delims==" %%A in ('wmic cpu get name /value ^| find "="') do echo CPU           : %%A
echo.
echo Product Key:
powershell -NoProfile -Command "(Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey"
echo.
echo Activation:
cscript //nologo %windir%\system32\slmgr.vbs /xpr
echo.
echo IPv4 / Gateway:
ipconfig | findstr /i "IPv4 Default Gateway"
echo.
echo BitLocker:
manage-bde -status C: | findstr /i "Protection Conversion Percentage"
echo.
pause
