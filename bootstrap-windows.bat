@echo off
setlocal EnableExtensions

REM One-shot bootstrap for a fresh Windows machine.
REM Installs into C:\Dream Generator, builds the Electron .exe, creates a
REM Desktop shortcut, and sets the app to launch on login/boot.
REM
REM Usage:
REM   bootstrap-windows.bat
REM   bootstrap-windows.bat "https://override-url"

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%bootstrap-windows.ps1"
set "URL_ARG=%~1"
set "DEFAULT_URL=https://cdn.vixisuite-staging.thefamousgroup.com/go/kiosk/9406cdab?code=EGfoK5oc26htkfnW"
set "RAW_PS1=https://raw.githubusercontent.com/CCavins/electron-print-test/main/bootstrap-windows.ps1"

if not "%URL_ARG%"=="" (
  set "URL=%URL_ARG%"
) else if not defined URL (
  set "URL=%DEFAULT_URL%"
)

echo Using kiosk URL:
echo   %URL%

if not exist "%PS1%" (
  echo bootstrap-windows.ps1 not found locally. Downloading from GitHub...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Invoke-WebRequest -Uri '%RAW_PS1%' -OutFile '%PS1%'"
  if errorlevel 1 (
    echo Failed to download bootstrap-windows.ps1
    pause
    exit /b 1
  )
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Url "%URL%"
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo.
  echo Bootstrap failed with exit code %ERR%.
  pause
  exit /b %ERR%
)

endlocal
