const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  // Downloads `url` natively in the main process, saving into the kiosk's
  // Dreams\Prints\s4x6 folder with no Save-As prompt. `filename` may omit the extension —
  // main.js appends one from the MIME type the server actually sent.
  // Resolves { path } once the file is on disk; rejects if the download fails,
  // so the page can re-arm its retry logic.
  triggerDownload: (url, filename) => ipcRenderer.invoke('download-file', { url, filename }),
})
