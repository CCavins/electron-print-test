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
#   8. Install Startup shortcut (Windows equivalent of a macOS launch plist) so the app starts on login/boot
#   9. Launch the app
#
# Usage:
#   bootstrap-windows.bat
#   bootstrap-windows.bat "https://override-url"
#
# Optional:
#   -DownloadDir "C:\path\to\Dreams"
#   -Windowed
#   -SkipLaunch
#   -SkipStartup

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
$DefaultKioskUrl = "https://cdn.vixisuite.thefamousgroup.com/go/kiosk/794f74e0?code=uifizkeqdKIMQQUe"

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    if (Test-IsAdmin) { return }

    Write-Host "Administrator rights needed to install into $TargetDir" -ForegroundColor Yellow
    $argsList = @(
        "-NoProfile"
        "-ExecutionPolicy", "Bypass"
        "-File", "`"$PSCommandPath`""
    )
    if ($Url) { $argsList += @("-Url", "`"$Url`"") }
    if ($RepoUrl) { $argsList += @("-RepoUrl", "`"$RepoUrl`"") }
    if ($TargetDir) { $argsList += @("-TargetDir", "`"$TargetDir`"") }
    if ($DownloadDir) { $argsList += @("-DownloadDir", "`"$DownloadDir`"") }
    if ($Windowed) { $argsList += "-Windowed" }
    if ($SkipLaunch) { $argsList += "-SkipLaunch" }
    if ($SkipStartup) { $argsList += "-SkipStartup" }

    $process = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argsList -Wait -PassThru
    exit $process.ExitCode
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Test-Command([string]$Name) {
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
        Invoke-WebRequest -Uri "https://nodejs.org/dist/v22.17.0/node-v22.17.0-x64.msi" -OutFile $installer
        Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /qn /norestart" -Wait -Verb RunAs
        Refresh-Path
    }

    if (-not ((Test-Command "node") -and (Test-Command "npm"))) {
        throw "Node.js was installed, but this shell cannot see it yet. Close this window, open a new PowerShell, and re-run the bootstrap."
    }
}

function Get-Repo {
    Write-Step "Getting repo into $TargetDir"

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

    # Empty or unrelated folder: if it has anything unexpected besides our install, still try clone into it
    $existing = @(Get-ChildItem -Force $TargetDir -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0 -and -not $hasPackage) {
        throw "Target folder already exists and does not look like this project: $TargetDir"
    }

    if (Install-GitIfNeeded) {
        Write-Host "Cloning $RepoUrl ..."
        # clone into temp then move, because git clone won't use a non-empty dir;
        # our dir may exist empty after New-Item
        $tmpClone = Join-Path $env:TEMP ("dream-generator-clone-" + [guid]::NewGuid().ToString("N"))
        git clone $RepoUrl $tmpClone
        Copy-Item -Path (Join-Path $tmpClone "*") -Destination $TargetDir -Recurse -Force
        # include hidden .git
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
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

    $inner = Get-ChildItem $extractRoot | Select-Object -First 1
    if (-not $inner) { throw "ZIP extract failed — empty archive." }

    Copy-Item -Path (Join-Path $inner.FullName "*") -Destination $TargetDir -Recurse -Force
}

function Build-App {
    Write-Step "Installing npm dependencies"
    Push-Location $TargetDir
    try {
        npm install
        if ($LASTEXITCODE -ne 0) { throw "npm install failed with exit code $LASTEXITCODE" }

        Write-Step "Building Windows Electron package"
        npm run build:win
        if ($LASTEXITCODE -ne 0) { throw "npm run build:win failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
}

function New-LaunchScript([string]$ExePath) {
    $launchBat = Join-Path $TargetDir "launch.bat"
    $downloadLine = ""
    if ($DownloadDir) {
        $downloadLine = "set `"DOWNLOAD_DIR=$DownloadDir`""
    }
    $windowedLine = ""
    if ($Windowed) {
        $windowedLine = "set `"WINDOWED=1`""
    }

    $content = @"
@echo off
REM Auto-generated by bootstrap-windows.ps1
set "URL=$Url"
$downloadLine
$windowedLine
start "" "$ExePath"
"@

    Set-Content -Path $launchBat -Value $content -Encoding ASCII
    return $launchBat
}

function New-Shortcut {
    param(
        [Parameter(Mandatory = $true)][string]$ShortcutPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $false)][string]$WorkingDirectory = "",
        [Parameter(Mandatory = $false)][string]$Description = "Dream Generator"
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
    $shortcut.Description = $Description
    $shortcut.Save()
}

function Install-DesktopShortcut([string]$LaunchBat) {
    Write-Step "Creating Desktop shortcut"
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "Dream Generator.lnk"
    New-Shortcut -ShortcutPath $shortcutPath -TargetPath $LaunchBat -WorkingDirectory $TargetDir -Description "Dream Generator kiosk"
    Write-Host "Desktop shortcut: $shortcutPath" -ForegroundColor Green
    return $shortcutPath
}

function Install-StartupShortcut([string]$LaunchBat) {
    # Windows equivalent of a macOS LaunchAgent plist: start on user login/boot.
    Write-Step "Installing launch-on-boot (Startup shortcut)"
    $startup = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startup "Dream Generator.lnk"
    New-Shortcut -ShortcutPath $shortcutPath -TargetPath $LaunchBat -WorkingDirectory $TargetDir -Description "Dream Generator kiosk (auto-start)"
    Write-Host "Startup shortcut: $shortcutPath" -ForegroundColor Green

    # Also drop a small marker/config next to the app documenting the boot launch.
    $plistNote = Join-Path $TargetDir "launch-on-boot.plist"
    $plist = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!--
  macOS LaunchAgent template (not used on Windows).
  On this Windows PC, boot/login launch is installed as a Startup shortcut:
  $shortcutPath

  To use this file on macOS instead:
    1. Replace LABEL/PATH/URL placeholders
    2. Copy to ~/Library/LaunchAgents/
    3. launchctl load ~/Library/LaunchAgents/com.olg.dreamgenerator.plist
-->
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.olg.dreamgenerator</string>
    <key>ProgramArguments</key>
    <array>
      <string>/Applications/Dream Generator.app/Contents/MacOS/Dream Generator</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
      <key>URL</key>
      <string>$Url</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
  </dict>
</plist>
"@
    Set-Content -Path $plistNote -Value $plist -Encoding UTF8
    return $shortcutPath
}

# --- main ---

Ensure-Admin

Write-Host "OLG Electron kiosk bootstrap" -ForegroundColor Cyan
Write-Host "Target: $TargetDir"

if (-not $Url) {
    $Url = $DefaultKioskUrl
}

$env:URL = $Url
if ($DownloadDir) { $env:DOWNLOAD_DIR = $DownloadDir }
if ($Windowed) { $env:WINDOWED = "1" }

Get-Repo
Install-NodeIfNeeded

Write-Host "Node: $(node -v) | npm: $(npm -v)" -ForegroundColor Green
Write-Host "URL:  $Url" -ForegroundColor Green

Build-App

$distDir = Join-Path $TargetDir "dist"
$portable = Get-ChildItem -Path $distDir -Filter "*portable*.exe" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $portable) {
    throw "Build finished but no portable .exe was found in $distDir"
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
Write-Host "Install folder:     $TargetDir"
Write-Host "Portable exe:       $rootExe"
Write-Host "Launcher:           $launchBat"
Write-Host "Desktop shortcut:   $desktopShortcut"
if ($startupShortcut) {
    Write-Host "Launch on boot:     $startupShortcut"
}
Write-Host ""
Write-Host "The app will start automatically when this Windows user logs in." -ForegroundColor Yellow
Write-Host "(Windows uses a Startup shortcut; .plist files are for macOS.)" -ForegroundColor Yellow

if (-not $SkipLaunch) {
    Write-Step "Launching app"
    Start-Process -FilePath $launchBat
}
