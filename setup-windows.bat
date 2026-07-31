@echo off
cd /d "%~dp0"

echo Running Windows setup...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1"
if errorlevel 1 (
  echo.
  echo Setup failed. If PowerShell blocked the script, try:
  echo   powershell -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1"
  pause
  exit /b 1
)
