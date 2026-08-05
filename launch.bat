@echo off
REM Start Hot Folder Print (wait until running + minimized), wait 30s for the
REM machine to settle, then launch Dream Generator.
REM Paths assume install at C:\Dream Generator

taskkill /F /IM DreamGenerator.exe /T >nul 2>&1
taskkill /F /IM "Dream Generator.exe" /T >nul 2>&1

REM --- Ensure Hot Folder Print is up and minimized before the kiosk ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure-hotfolder.ps1"
if errorlevel 1 (
  echo WARNING: Hot Folder Print was not confirmed running. Continuing anyway.
)

timeout /t 30 /nobreak >nul

set "URL=https://cdn.vixisuite-staging.thefamousgroup.com/go/kiosk/9406cdab?code=EGfoK5oc26htkfnW"
set "DOWNLOAD_DIR=%USERPROFILE%\Desktop\Dreams\Prints\s4x6"
start "" "C:\Dream Generator\DreamGenerator.exe"
