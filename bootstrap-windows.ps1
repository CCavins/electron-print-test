# Bootstrap the OLG Electron kiosk onto this Windows machine.
#
# Sequence:
#   1. Elevate if needed (writes to C:\Dream Generator)
#   2. Clone/update repo into C:\Dream Generator
#   3. Install Node.js LTS if needed
#   4. npm install
#   5. Build Windows Electron package
#   6. Write launch.bat (sets URL, starts exe)
#   7. Create Desktop shortcut
#   8. Install Startup shortcut so the app starts on login
#   9. Launch the app
#
# Usage:
#   bootstrap-windows.bat
#   bootstrap-windows.bat "https://override-url"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Url = $env:URL,

    [Parameter(Mandatory = $false)]
    [string]$RepoUrl = "https://github.com/CCavins/electron-print-test.git",

    [Parameter(Mandatory = $false)]
    [string]$TargetDir = "C:\Dream Generator",

    [Parameter(Mandatory = $false)]
    [string]$DownloadDir = $env:DOWNLOAD_DIR,

    [switch]$Windowed,

    [switch]$SkipLaunch,

    [switch]$SkipStartup
)

$ErrorActionPreference = "Stop"
$DefaultKioskUrl = "https://api.vixisuite.thefamousgroup.com/go/i/uifizkeqdKIMQQUe"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ("==> " + $Message) -ForegroundColor Cyan
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    if (Test-IsAdmin) { return }

    Write-Host ("Administrator rights needed to install into " + $TargetDir) -ForegroundColor Yellow

    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Url) { $argList += " -Url `"$Url`"" }
    if ($RepoUrl) { $argList += " -RepoUrl `"$RepoUrl`"" }
    if ($TargetDir) { $argList += " -TargetDir `"$TargetDir`"" }
    if ($DownloadDir) { $argList += " -DownloadDir `"$DownloadDir`"" }
    if ($Windowed) { $argList += " -Windowed" }
    if ($SkipLaunch) { $argList += " -SkipLaunch" }
    if ($SkipStartup) { $argList += " -SkipStartup" }

    $process = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList -Wait -PassThru
    exit $process.ExitCode
}

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-GitIfNeeded {
    if (Test-Command "git") { return $true }

    Write-Host "Git not found. Trying to install via winget..." -ForegroundColor Yellow
    if (Test-Command "winget") {
        winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements
        Refresh-Path
    }

    return (Test-Command "git")
}

function Install-NodeIfNeeded {
    if ((Test-Command "node") -and (Test-Command "npm")) { return }

    Write-Step "Installing Node.js LTS"
    if (Test-Command "winget") {
        winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
        Refresh-Path
    } else {
        $installer = Join-Path $env:TEMP "node-lts.msi"
        Write-Host "winget not available. Downloading Node.js MSI..." -ForegroundColor Yellow
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://nodejs.org/dist/v22.17.0/node-v22.17.0-x64.msi" -OutFile $installer -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /qn /norestart" -Wait -Verb RunAs
        Refresh-Path
    }

    if (-not ((Test-Command "node") -and (Test-Command "npm"))) {
        throw "Node.js was installed, but this shell cannot see it yet. Close this window, open a new PowerShell, and re-run the bootstrap."
    }
}

function Get-Repo {
    Write-Step ("Getting repo into " + $TargetDir)

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    if (Test-Path (Join-Path $TargetDir ".git")) {
        Write-Host "Repo already present. Pulling latest..."
        Push-Location $TargetDir
        try {
            git pull --ff-only
        } finally {
            Pop-Location
        }
        return
    }

    $hasPackage = Test-Path (Join-Path $TargetDir "package.json")
    if ($hasPackage) {
        Write-Host "Folder exists with package.json (no .git). Leaving files in place."
        return
    }

    $existing = @(Get-ChildItem -Force $TargetDir -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0 -and -not $hasPackage) {
        throw ("Target folder already exists and does not look like this project: " + $TargetDir)
    }

    if (Install-GitIfNeeded) {
        Write-Host ("Cloning " + $RepoUrl + " ...")
        $tmpClone = Join-Path $env:TEMP ("dream-generator-clone-" + [guid]::NewGuid().ToString("N"))
        git clone $RepoUrl $tmpClone
        Copy-Item -Path (Join-Path $tmpClone "*") -Destination $TargetDir -Recurse -Force
        if (Test-Path (Join-Path $tmpClone ".git")) {
            Copy-Item -Path (Join-Path $tmpClone ".git") -Destination (Join-Path $TargetDir ".git") -Recurse -Force
        }
        Remove-Item $tmpClone -Recurse -Force
        return
    }

    Write-Host "Git unavailable. Downloading ZIP from GitHub..." -ForegroundColor Yellow
    $zipUrl = "https://github.com/CCavins/electron-print-test/archive/refs/heads/main.zip"
    $zipPath = Join-Path $env:TEMP "electron-print-test-main.zip"
    $extractRoot = Join-Path $env:TEMP "electron-print-test-extract"

    if (Test-Path $extractRoot) { Remove-Item $extractRoot -Recurse -Force }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

    $inner = Get-ChildItem $extractRoot | Select-Object -First 1
    if (-not $inner) { throw "ZIP extract failed - empty archive." }

    Copy-Item -Path (Join-Path $inner.FullName "*") -Destination $TargetDir -Recurse -Force
}

function Build-App {
    Write-Step "Installing npm dependencies"
    Push-Location $TargetDir
    try {
        npm install
        if ($LASTEXITCODE -ne 0) { throw ("npm install failed with exit code " + $LASTEXITCODE) }

        Write-Step "Building Windows Electron package"
        npm run build:win
        if ($LASTEXITCODE -ne 0) { throw ("npm run build:win failed with exit code " + $LASTEXITCODE) }
    } finally {
        Pop-Location
    }
}

function New-LaunchScript {
    param([string]$ExePath)

    $resolvedDownloadDir = $DownloadDir
    if (-not $resolvedDownloadDir) {
        $resolvedDownloadDir = Join-Path ([Environment]::GetFolderPath("Desktop")) "Dreams\Prints\s4x6"
    }

    $launchBat = Join-Path $TargetDir "launch.bat"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("@echo off")
    $lines.Add("REM Auto-generated by bootstrap-windows.ps1")
    $lines.Add('REM Always ensure Hot Folder Print. Manual: 3s delay. Boot: 30s delay.')
    $lines.Add("taskkill /F /IM DreamGenerator.exe /T >nul 2>&1")
    $lines.Add('taskkill /F /IM "Dream Generator.exe" /T >nul 2>&1')
    $lines.Add('powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure-hotfolder.ps1"')
    $lines.Add("if errorlevel 1 (")
    $lines.Add("  echo WARNING: Hot Folder Print was not confirmed running. Continuing anyway.")
    $lines.Add(")")
    $lines.Add('if /i "%~1"=="boot" (')
    $lines.Add("  timeout /t 30 /nobreak >nul")
    $lines.Add(") else (")
    $lines.Add("  timeout /t 3 /nobreak >nul")
    $lines.Add(")")
    $lines.Add(('set "URL=' + $Url + '"'))
    $lines.Add(('set "DOWNLOAD_DIR=' + $resolvedDownloadDir + '"'))
    if ($Windowed) {
        $lines.Add('set "WINDOWED=1"')
    }
    $lines.Add(('start "" "' + $ExePath + '"'))

    Set-Content -Path $launchBat -Value $lines -Encoding ASCII
    return $launchBat
}

function New-Shortcut {
    param(
        [Parameter(Mandatory = $true)][string]$ShortcutPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $false)][string]$WorkingDirectory = "",
        [Parameter(Mandatory = $false)][string]$Description = "Dream Generator",
        [Parameter(Mandatory = $false)][string]$Arguments = ""
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
    $shortcut.Description = $Description
    $shortcut.Save()
}

function Install-DesktopShortcut {
    param([string]$LaunchBat)

    Write-Step "Creating Desktop shortcut"
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "Dream Generator.lnk"
    New-Shortcut -ShortcutPath $shortcutPath -TargetPath $LaunchBat -WorkingDirectory $TargetDir -Description "Dream Generator kiosk"
    Write-Host ("Desktop shortcut: " + $shortcutPath) -ForegroundColor Green
    return $shortcutPath
}

function Install-StartupShortcut {
    param([string]$LaunchBat)

    Write-Step "Installing launch-on-boot (Startup shortcut)"
    $startup = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startup "Dream Generator.lnk"
    # "boot" arg enables Hot Folder ensure + 30s delay; Desktop shortcut omits it.
    New-Shortcut -ShortcutPath $shortcutPath -TargetPath $LaunchBat -WorkingDirectory $TargetDir -Description "Dream Generator kiosk auto-start" -Arguments "boot"
    Write-Host ("Startup shortcut: " + $shortcutPath + " (args: boot)") -ForegroundColor Green
    return $shortcutPath
}

# --- main ---

Ensure-Admin

Write-Host "OLG Electron kiosk bootstrap" -ForegroundColor Cyan
Write-Host ("Target: " + $TargetDir)

if (-not $Url) {
    $Url = $DefaultKioskUrl
}

$env:URL = $Url
if ($DownloadDir) { $env:DOWNLOAD_DIR = $DownloadDir }
if ($Windowed) { $env:WINDOWED = "1" }

Get-Repo
Install-NodeIfNeeded

Write-Host ("Node: " + (node -v) + " | npm: " + (npm -v)) -ForegroundColor Green
Write-Host ("URL:  " + $Url) -ForegroundColor Green

Build-App

$distDir = Join-Path $TargetDir "dist"
$portable = Get-ChildItem -Path $distDir -Filter "*portable*.exe" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $portable) {
    throw ("Build finished but no portable .exe was found in " + $distDir)
}

$rootExe = Join-Path $TargetDir "DreamGenerator.exe"
Copy-Item -Path $portable.FullName -Destination $rootExe -Force

$launchBat = New-LaunchScript -ExePath $rootExe
$desktopShortcut = Install-DesktopShortcut -LaunchBat $launchBat

$startupShortcut = $null
if (-not $SkipStartup) {
    $startupShortcut = Install-StartupShortcut -LaunchBat $launchBat
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host ("Install folder:     " + $TargetDir)
Write-Host ("Portable exe:       " + $rootExe)
Write-Host ("Launcher:           " + $launchBat)
Write-Host ("Desktop shortcut:   " + $desktopShortcut)
if ($startupShortcut) {
    Write-Host ("Launch on boot:     " + $startupShortcut)
}
Write-Host ""
Write-Host "The app will start automatically when this Windows user logs in." -ForegroundColor Yellow

if (-not $SkipLaunch) {
    Write-Step "Launching app"
    Start-Process -FilePath $launchBat
}
