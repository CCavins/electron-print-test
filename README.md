# Electron Print Test

Fullscreen Electron kiosk that loads the Vixi Dream Generator and auto-saves downloaded images.

## What it does

- Opens the Dream Generator URL in a fullscreen window
- Hides the menu bar for a kiosk-style experience
- Saves image downloads automatically to `Desktop/Dreams/Prints` (no Save As dialog)
- Creates the `Dreams/Prints` folders if they do not exist
- Avoids overwriting existing files by appending a numeric suffix

Press **Escape** to leave fullscreen during development.

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
| `main.js` | Electron main process — window, fullscreen, download handling |
| `package.json` | App metadata and scripts |

## Notes

Saved images land at:

```text
~/Desktop/Dreams/Prints/
```
