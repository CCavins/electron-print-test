@echo off
REM Force-quit any running instance, wait 3s, then launch.
REM Paths assume install at C:\Dream Generator

taskkill /F /IM DreamGenerator.exe /T >nul 2>&1
taskkill /F /IM "Dream Generator.exe" /T >nul 2>&1
timeout /t 3 /nobreak >nul

set "URL=https://cdn.vixisuite.thefamousgroup.com/go/kiosk/794f74e0?code=uifizkeqdKIMQQUe"
start "" "C:\Dream Generator\DreamGenerator.exe"
