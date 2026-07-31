# Installs Node.js (if needed), installs dependencies, builds a Windows .exe,
# and launches the portable executable.
#
# Optional override:
#   set URL=https://...
#   setup-windows.bat
#
# Optional:
#   DOWNLOAD_DIR  (default: Desktop\Dreams)
#   WINDOWED=1    (normal window instead of kiosk)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

if (-not $env:URL) {
    $env:URL = "https://cdn.vixisuite.thefamousgroup.com/go/kiosk/794f74e0?code=uifizkeqdKIMQQUe"
}

function Test-NodeInstalled {
    try {
        $null = Get-Command node -ErrorAction Stop
        $null = Get-Command npm -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Install-NodeJs {
    Write-Host "Node.js not found. Installing Node.js LTS..." -ForegroundColor Yellow

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path", "User")
        return
    }

    Write-Host "winget not available. Downloading Node.js LTS installer..." -ForegroundColor Yellow
    $installer = Join-Path $env:TEMP "node-lts.msi"
    Invoke-WebRequest -Uri "https://nodejs.org/dist/v22.17.0/node-v22.17.0-x64.msi" -OutFile $installer
    Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /qn /norestart" -Wait -Verb RunAs
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Host "==> OLG kiosk shell setup / build" -ForegroundColor Cyan
Write-Host "Project folder: $PSScriptRoot"

Write-Host "URL: $env:URL" -ForegroundColor Green

if (-not (Test-NodeInstalled)) {
    Install-NodeJs
    if (-not (Test-NodeInstalled)) {
        Write-Host "Node.js was installed, but this terminal cannot see it yet." -ForegroundColor Red
        Write-Host "Close this window, open a new PowerShell, then run:" -ForegroundColor Red
        Write-Host "  cd `"$PSScriptRoot`""
        Write-Host "  .\setup-windows.ps1"
        exit 1
    }
}

$nodeVersion = node -v
$npmVersion = npm -v
Write-Host "Node: $nodeVersion | npm: $npmVersion" -ForegroundColor Green

Write-Host "==> Installing dependencies (npm install)..." -ForegroundColor Cyan
npm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "npm install failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "==> Building Windows executable (npm run build:win)..." -ForegroundColor Cyan
npm run build:win
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

$distDir = Join-Path $PSScriptRoot "dist"
$portable = Get-ChildItem -Path $distDir -Filter "*portable*.exe" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$installer = Get-ChildItem -Path $distDir -Filter "*.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch "portable" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

Write-Host ""
Write-Host "Build complete. Output folder:" -ForegroundColor Green
Write-Host "  $distDir"

if ($portable) {
    Write-Host "Portable app:" -ForegroundColor Green
    Write-Host "  $($portable.FullName)"
}

if ($installer) {
    Write-Host "Installer:" -ForegroundColor Green
    Write-Host "  $($installer.FullName)"
}

if ($portable) {
    Write-Host ""
    Write-Host "==> Launching portable executable..." -ForegroundColor Cyan
    # URL / DOWNLOAD_DIR / WINDOWED are already in this process environment
    # and are inherited by the child process.
    Start-Process -FilePath $portable.FullName
} elseif ($installer) {
    Write-Host ""
    Write-Host "==> Launching installer..." -ForegroundColor Cyan
    Start-Process -FilePath $installer.FullName
} else {
    Write-Host "Could not find a built .exe in dist\. Open that folder manually." -ForegroundColor Yellow
    exit 1
}
