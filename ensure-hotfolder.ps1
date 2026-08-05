# Ensures DNP Hot Folder Print is running and minimized.
# Called by launch.bat before Dream Generator starts.
#
# Exit 0 = process is running and minimize was attempted
# Exit 1 = could not find or start Hot Folder Print within the timeout

param(
    [int]$TimeoutSeconds = 60,
    [int]$PollSeconds = 2
)

$ErrorActionPreference = "SilentlyContinue"

$ProcessNames = @(
    "HotFolderPrint",
    "Hot Folder",
    "HotFolder"
)

function Find-HotFolderExe {
    $candidates = @(
        (Join-Path $env:ProgramFiles "DNP Imagingcomm America Corporation\Hot Folder Print\HotFolderPrint.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "DNP Imagingcomm America Corporation\Hot Folder Print\HotFolderPrint.exe"),
        "C:\DNP\HotFolderPrint\HotFolderPrint.exe",
        "C:\DNP\Hot Folder\Hot Folder.exe",
        "C:\DNP\Hot Folder\HotFolder.exe",
        (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Hot Folder Print\Hot Folder Print.lnk")
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }
    return $null
}

function Get-HotFolderProcesses {
    foreach ($name in $ProcessNames) {
        $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        if ($procs.Count -gt 0) { return $procs }
    }
    return @()
}

function Minimize-HotFolderWindows {
    param([System.Diagnostics.Process[]]$Processes)

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class HfpWin {
    public const int SW_MINIMIZE = 6;
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@ -ErrorAction SilentlyContinue

    foreach ($proc in $Processes) {
        try { $proc.Refresh() } catch {}
        $hwnd = $proc.MainWindowHandle
        if ($hwnd -ne [IntPtr]::Zero) {
            [void][HfpWin]::ShowWindow($hwnd, [HfpWin]::SW_MINIMIZE)
        }
    }
}

$exe = Find-HotFolderExe
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$started = $false

while ((Get-Date) -lt $deadline) {
    $procs = Get-HotFolderProcesses

    if ($procs.Count -eq 0) {
        if (-not $exe) {
            Write-Host "Hot Folder Print not found on this PC." -ForegroundColor Red
            exit 1
        }
        if (-not $started) {
            Write-Host ("Starting Hot Folder Print: " + $exe)
            Start-Process -FilePath $exe -WindowStyle Minimized
            $started = $true
        }
        Start-Sleep -Seconds $PollSeconds
        continue
    }

    # Process is up; wait briefly for a main window, then minimize.
    $readyAt = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $readyAt) {
        foreach ($p in $procs) {
            try { $p.Refresh() } catch {}
        }
        $withWindow = @($procs | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
        if ($withWindow.Count -gt 0) {
            Minimize-HotFolderWindows -Processes $withWindow
            Write-Host "Hot Folder Print is running and minimized." -ForegroundColor Green
            exit 0
        }
        Start-Sleep -Milliseconds 500
        $procs = Get-HotFolderProcesses
        if ($procs.Count -eq 0) { break }
    }

    # Tray-only / no MainWindowHandle yet — process exists; treat as ready.
    Minimize-HotFolderWindows -Processes $procs
    Write-Host "Hot Folder Print is running (minimize attempted)." -ForegroundColor Green
    exit 0
}

Write-Host "Timed out waiting for Hot Folder Print to start." -ForegroundColor Red
exit 1
