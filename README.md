# Electron Print Test

Fullscreen Electron kiosk that loads the Vixi Dream Generator and auto-saves downloaded images.

## What it does

- Opens the Dream Generator URL in a fullscreen window
- Hides the menu bar for a kiosk-style experience
- Listens for download events via IPC (`electronAPI.triggerDownload`)
- Saves files automatically to `Desktop/Dreams/Prints` (no Save As dialog)
- Creates the `Dreams/Prints` folders if they do not exist
- Avoids overwriting existing files by appending a numeric suffix

Press **Escape** to leave fullscreen during development.

## Download events

The preload exposes:

```js
window.electronAPI.triggerDownload(url, filename);
window.electronAPI.onDownloadStatus((result) => { /* success | failed */ });
```

The page can also trigger a save with:

```js
window.dispatchEvent(new CustomEvent('download-file', {
  detail: { url: 'https://example.com/image.png', filename: 'dream.png' }
}));

// or
window.postMessage({ type: 'download-file', url, filename }, '*');
```

Clicks on `<a download>` links are intercepted and routed through the same path.

## Requirements

- [Node.js](https://nodejs.org/) (LTS recommended)
- npm

## Setup

```bash
npm install
```

## Run

```bash
npm start
```

## Project structure

| File | Purpose |
|------|---------|
| `main.js` | Electron main process — window, IPC, download path handling |
| `preload.js` | Bridges page events to the main process (`electronAPI`) |
| `package.json` | App metadata and scripts |

## Notes

Saved images land at:

```text
~/Desktop/Dreams/Prints/
```
