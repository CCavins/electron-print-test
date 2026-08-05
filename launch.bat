@echo off
REM Always ensure Hot Folder Print is running + minimized.
REM Manual launch (Desktop shortcut): 3s delay, then Dream Generator.
REM Boot launch (Startup shortcut with "boot" arg): 30s settle delay, then Dream Generator.
REM Paths assume install at C:\Dream Generator

taskkill /F /IM DreamGenerator.exe /T >nul 2>&1
taskkill /F /IM "Dream Generator.exe" /T >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure-hotfolder.ps1"
if errorlevel 1 (
  echo WARNING: Hot Folder Print was not confirmed running. Continuing anyway.
)

if /i "%~1"=="boot" (
  timeout /t 30 /nobreak >nul
) else (
  timeout /t 3 /nobreak >nul
)

set "URL=https://api.vixisuite.thefamousgroup.com/go/i/uifizkeqdKIMQQUe"
set "DOWNLOAD_DIR=%USERPROFILE%\Desktop\Dreams\Prints\s4x6"
start "" "C:\Dream Generator\DreamGenerator.exe"
