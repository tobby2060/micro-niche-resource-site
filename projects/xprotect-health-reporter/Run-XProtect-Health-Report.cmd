@echo off
setlocal
pushd "%~dp0"
echo.
echo XProtect Hardware and Camera Health Reporter
echo ============================================
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-XProtectHealthReport.ps1" -InstallModule -OpenReport
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
    echo Report failed with exit code %RC%.
    echo Review the error above. The common causes are login permissions or TCP 7563 to the Recording Servers.
) else (
    echo Report completed successfully.
)
echo.
pause
popd
exit /b %RC%
