@echo off
REM Manual launch (Desktop shortcut): 3s after taskkill, then start Dream Generator.
REM Boot launch (Startup shortcut with "boot" arg): ensure Hot Folder Print is
REM running + minimized, wait 30s for the PC to settle, then start Dream Generator.
REM Paths assume install at C:\Dream Generator

taskkill /F /IM DreamGenerator.exe /T >nul 2>&1
taskkill /F /IM "Dream Generator.exe" /T >nul 2>&1

if /i "%~1"=="boot" (
  REM --- Boot-only: Hot Folder Print ready, then settle delay ---
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure-hotfolder.ps1"
  if errorlevel 1 (
    echo WARNING: Hot Folder Print was not confirmed running. Continuing anyway.
  )
  timeout /t 30 /nobreak >nul
) else (
  REM --- Manual / Desktop: short delay after taskkill ---
  timeout /t 3 /nobreak >nul
)

set "URL=https://api.vixisuite.thefamousgroup.com/go/i/uifizkeqdKIMQQUe"
set "DOWNLOAD_DIR=%USERPROFILE%\Desktop\Dreams\Prints\s4x6"
start "" "C:\Dream Generator\DreamGenerator.exe"
