// Experimental Electron shell for the kiosk. The Chrome --kiosk path in
// launch/ is still the deployed setup (see ../README.md "Why no Electron");
// this shell exists for when we need hard-enforced download destinations
// instead of Chrome download policies.
//
// Run with:
//   npm start
//   URL=https://... npm start   (optional override)
//
// Optional env:
//   DOWNLOAD_DIR  where dreams are saved (default: Desktop\Dreams\Prints\s4x6)
//   WINDOWED=1    normal resizable window instead of kiosk fullscreen, for local testing
const { app, BrowserWindow, ipcMain } = require('electron')
const path = require('path')
const fs = require('fs')

const DEFAULT_KIOSK_URL =
  'https://api.vixisuite.thefamousgroup.com/go/i/uifizkeqdKIMQQUe'
const pageUrl = process.env.URL || DEFAULT_KIOSK_URL

// Where downloads land: Desktop\Dreams\Prints\s4x6 unless DOWNLOAD_DIR overrides it.
function resolveDownloadDir() {
  return process.env.DOWNLOAD_DIR || path.join(app.getPath('desktop'), 'Dreams', 'Prints', 's4x6')
}

// The download item reports the MIME type the server actually sent; used to
// pick an extension when the renderer passes a bare filename without one.
function extFromMimeType(mimeType) {
  if (!mimeType) return 'jpg'
  if (mimeType.includes('png')) return 'png'
  if (mimeType.includes('webp')) return 'webp'
  return 'jpg'
}

let mainWindow

function createWindow() {
  const windowed = process.env.WINDOWED === '1'
  mainWindow = new BrowserWindow({
    kiosk: !windowed,
    width: 1280,
    height: 800,
    autoHideMenuBar: true,
    backgroundColor: '#000000',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  })

  mainWindow.loadURL(pageUrl)
}

// Renderer hands us the asset URL + desired filename (see preload.js); the
// main process downloads it natively and saves into Desktop\Dreams\Prints\s4x6 with
// no Save-As prompt. Resolves with the saved path so the page's await/retry
// logic (one-shot print button) keeps working; rejects on any failure.
ipcMain.handle('download-file', (event, { url, filename }) => {
  const contents = event.sender
  const downloadDir = resolveDownloadDir()
  fs.mkdirSync(downloadDir, { recursive: true })

  return new Promise((resolve, reject) => {
    const onWillDownload = (_event, item) => {
      clearTimeout(startTimer)
      // basename() so a buggy filename can't escape the download folder.
      let safeName = path.basename(String(filename || 'dream'))
      if (!path.extname(safeName)) safeName += `.${extFromMimeType(item.getMimeType())}`
      const savePath = path.join(downloadDir, safeName)
      item.setSavePath(savePath)

      item.once('done', (_doneEvent, state) => {
        if (state === 'completed') resolve({ path: savePath })
        else reject(new Error(`Download ${state}`))
      })
    }

    // If the download never starts (dead URL, blocked scheme), fail instead
    // of leaving the renderer's await — and the print button — hanging.
    const startTimer = setTimeout(() => {
      contents.session.removeListener('will-download', onWillDownload)
      reject(new Error('Download did not start within 30s'))
    }, 30_000)

    contents.session.once('will-download', onWillDownload)
    contents.downloadURL(url)
  })
})

app.whenReady().then(() => {
  createWindow()
})

app.on('window-all-closed', () => app.quit())
