# Electron kiosk shell (experimental)

An alternative to the Chrome `--kiosk` setup in the parent directory (see [../README.md](../README.md), "Why no Electron"). The Chrome path is still the deployed one; this shell exists for when we need a **hard-enforced download destination** — the main process saves files itself instead of relying on Chrome download policy keys.

## How it works

- `main.js` opens the kiosk URL fullscreen (`kiosk: true`) with `preload.js` injected.
- `preload.js` exposes `window.electronAPI.triggerDownload(url, filename)` to the page.
- The OLG kiosk page (`components/kiosk_apps/KioskOLG.vue`) detects `window.electronAPI` and hands the dream URL to the shell instead of doing an anchor-click browser download. The main process downloads it natively straight into `Desktop\Dreams\Prints` — no Save-As prompt, no Chrome policy needed.
- `filename` may omit the extension; the shell appends one from the MIME type the server sent.
- In a plain browser (`window.electronAPI` absent) the page falls back to the existing blob + anchor download, so nothing changes for the deployed Chrome kiosks.

## Running

```sh
cd launch/electron
npm install
npm start
```

Default kiosk URL:

`https://api.vixisuite.thefamousgroup.com/go/i/uifizkeqdKIMQQUe`

Environment variables:

| Var | Default | Purpose |
|---|---|---|
| `URL` | production kiosk URL above | Optional override for the page to load. |
| `DOWNLOAD_DIR` | `Desktop\Dreams\Prints` | Where dreams are saved. |
| `WINDOWED` | unset | Set to `1` for a normal resizable window instead of kiosk fullscreen (local testing). |

## Windows: one-shot bootstrap (recommended)

Run as Administrator (it will prompt to elevate):

```bat
bootstrap-windows.bat
```

That script will, in order:

1. Clone (or update) this repo into `C:\Dream Generator`
2. Install Node.js LTS if missing (`winget`, or MSI fallback)
3. Run `npm install`
4. Build the Windows Electron package (`npm run build:win`)
5. Copy the portable exe to `C:\Dream Generator\DreamGenerator.exe`
6. Write `C:\Dream Generator\launch.bat` (sets `URL` and starts the app)
7. Create a **Desktop shortcut** named `Dream Generator`
8. Install **launch-on-login** via the Windows Startup folder (Windows equivalent of a macOS `.plist`)
9. Launch the app

If Git is not installed, it downloads the repo ZIP from GitHub instead.

After setup:

- Desktop shortcut → `Dream Generator`
- Auto-start on login → Startup folder shortcut
- Manual launch → `C:\Dream Generator\launch.bat`

### macOS launch-on-boot (plist)

`.plist` files are a macOS feature. Use `com.olg.dreamgenerator.plist` with `launchctl` on Mac. On Windows, the bootstrap installs a Startup shortcut instead.

### Build only (repo already on disk)

```bat
cd "C:\Dream Generator"
setup-windows.bat
```

| File | Purpose |
|------|---------|
| `C:\Dream Generator\DreamGenerator.exe` | Portable app |
| `C:\Dream Generator\launch.bat` | Starts app with configured `URL` |
| Desktop `Dream Generator.lnk` | Shortcut to the launcher |
| Startup `Dream Generator.lnk` | Auto-start on login |
| `com.olg.dreamgenerator.plist` | macOS LaunchAgent template only |

Manual build:

```bat
npm install
npm run build:win
```

## Not yet handled

- Crash relaunch / watchdog.
