@echo off
REM Force-quit any running instance, wait 3s, then launch.
REM Paths assume install at C:\Dream Generator

taskkill /F /IM DreamGenerator.exe /T >nul 2>&1
taskkill /F /IM "Dream Generator.exe" /T >nul 2>&1
timeout /t 3 /nobreak >nul

set "URL=https://cdn.vixisuite-staging.thefamousgroup.com/go/kiosk/9406cdab?code=EGfoK5oc26htkfnW"
set "DOWNLOAD_DIR=%USERPROFILE%\Desktop\Dreams\Prints"
start "" "C:\Dream Generator\DreamGenerator.exe"
